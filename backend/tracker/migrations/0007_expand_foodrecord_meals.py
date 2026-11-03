from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("tracker", "0006_foodrecord_time_specified")]

    operations = [
        migrations.AlterField(
            model_name="foodrecord",
            name="meal_type",
            field=models.CharField(
                choices=[
                    ("breakfast", "Breakfast"),
                    ("brunch", "Brunch"),
                    ("elevenses", "Morning snack (Elevenses)"),
                    ("lunch", "Lunch"),
                    ("afternoon_tea", "Afternoon tea"),
                    ("dinner", "Dinner"),
                    ("supper", "Supper"),
                    ("snack", "Snack"),
                ],
                max_length=16,
            ),
        ),
    ]
