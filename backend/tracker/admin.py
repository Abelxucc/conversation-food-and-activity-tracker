from django import forms
from django.contrib import admin, messages
from django.contrib.auth import get_user_model, update_session_auth_hash
from django.contrib.auth.forms import SetPasswordForm
from django.core.exceptions import PermissionDenied
from django.db import transaction
from django.http import Http404, HttpResponseRedirect
from django.template.response import TemplateResponse
from django.urls import path, reverse
from django.utils import timezone
from django.utils.html import format_html

from .models import AccountProfile, PasswordResetRequest


class AdministratorResetForm(SetPasswordForm):
    identity_verified = forms.BooleanField(
        label="I have independently verified this user's identity",
        help_text="Knowing the email address alone is not proof of identity.",
        required=True,
    )
    admin_notes = forms.CharField(
        label="Verification and handling notes",
        widget=forms.Textarea(attrs={"rows": 3}),
        required=True,
        help_text="Record how identity was verified. Do not record passwords or other secrets.",
    )


@admin.register(AccountProfile)
class AccountProfileAdmin(admin.ModelAdmin):
    list_display = ("email", "phone_number", "gender", "height_cm", "weight_kg", "age")
    search_fields = ("email", "phone_number")
    readonly_fields = ("user", "email", "phone_number", "gender", "height_cm", "weight_kg", "age")

    def has_add_permission(self, request):
        return False


@admin.register(PasswordResetRequest)
class PasswordResetRequestAdmin(admin.ModelAdmin):
    list_display = ("email", "status", "created_at", "handled_by", "handled_at")
    list_filter = ("status", "created_at")
    search_fields = ("email",)
    ordering = ("-created_at",)
    actions = ("close_requests",)
    readonly_fields = (
        "email", "status", "created_at", "account", "handled_by", "handled_at",
        "identity_verified_by", "identity_verified_at", "reset_password_action",
    )
    fields = (
        "email", "status", "created_at", "reset_password_action", "account",
        "identity_verified_by", "identity_verified_at", "handled_by", "handled_at",
        "admin_notes",
    )

    def has_add_permission(self, request):
        return False

    @admin.display(description="Identity verification and password reset")
    def reset_password_action(self, obj):
        if obj.status != PasswordResetRequest.Status.PENDING:
            return "This request has already been handled."
        url = reverse("admin:tracker_passwordresetrequest_reset_password", args=[obj.pk])
        return format_html('<a class="button" href="{}">Review identity and reset password</a>', url)

    def get_urls(self):
        return [
            path(
                "<int:object_id>/reset-password/",
                self.admin_site.admin_view(self.reset_password_view),
                name="tracker_passwordresetrequest_reset_password",
            ),
        ] + super().get_urls()

    @admin.action(description="Close selected pending requests without resetting passwords", permissions=["change"])
    def close_requests(self, request, queryset):
        count = queryset.filter(status=PasswordResetRequest.Status.PENDING).update(
            status=PasswordResetRequest.Status.CLOSED,
            handled_by=request.user,
            handled_at=timezone.now(),
        )
        self.message_user(request, f"Closed {count} pending request(s). No passwords were changed.")

    def reset_password_view(self, request, object_id):
        # Staff must be allowed to handle requests AND change authentication
        # users. Anonymous users cannot access this endpoint via the public API.
        if not self.has_change_permission(request) or not request.user.has_perm("auth.change_user"):
            raise PermissionDenied

        with transaction.atomic():
            try:
                ticket = PasswordResetRequest.objects.select_for_update().get(pk=object_id)
            except PasswordResetRequest.DoesNotExist as error:
                raise Http404 from error
            if ticket.status != PasswordResetRequest.Status.PENDING:
                raise PermissionDenied("This request has already been handled.")

            users = list(get_user_model().objects.select_for_update().filter(
                email__iexact=ticket.email, is_active=True,
            )[:2])
            user = users[0] if len(users) == 1 and users[0].has_usable_password() else None
            form = None
            if user is not None:
                form = AdministratorResetForm(
                    user,
                    request.POST if request.method == "POST" else None,
                    initial={"admin_notes": ticket.admin_notes},
                )
                if request.method == "POST" and form.is_valid():
                    form.save()
                    update_session_auth_hash(request, user)
                    now = timezone.now()
                    ticket.status = PasswordResetRequest.Status.COMPLETED
                    ticket.account = user
                    ticket.handled_by = request.user
                    ticket.handled_at = now
                    ticket.identity_verified_by = request.user
                    ticket.identity_verified_at = now
                    ticket.admin_notes = form.cleaned_data["admin_notes"]
                    ticket.save()
                    self.log_change(request, ticket, "Identity verified and account password reset.")
                    self.message_user(request, "Password reset completed. The request has been marked completed.", messages.SUCCESS)
                    return HttpResponseRedirect(reverse("admin:tracker_passwordresetrequest_change", args=[ticket.pk]))

            context = {
                **self.admin_site.each_context(request),
                "title": "Review identity and reset password",
                "opts": self.model._meta,
                "original": ticket,
                "ticket": ticket,
                "target_user": user,
                "form": form,
                "back_url": reverse("admin:tracker_passwordresetrequest_change", args=[ticket.pk]),
            }
            return TemplateResponse(request, "tracker/admin/reset_password.html", context)
