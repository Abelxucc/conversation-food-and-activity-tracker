from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("tracker", "0005_alter_foodentry_options_alter_foodentry_quantity_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="foodrecord",
            name="time_specified",
            field=models.BooleanField(default=True),
        ),
    ]
