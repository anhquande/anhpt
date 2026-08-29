# Health Tracking Product Requirements

Status: Proposed MVP

## 1. Product vision

AnhPT should become a single place where users can exercise and monitor how their health changes over time, instead of requiring a separate weight-tracking app.

The first Health release focuses on weight tracking and workout correlation. The architecture should remain extensible for future metrics such as blood pressure, blood lipids, body fat, and platform health integrations.

## 2. Goals

- Make weight entry extremely fast and easy to understand.
- Help users see weight trends over time.
- Correlate workout activity with weight without claiming medical causation.
- Motivate users with understandable progress and conservative forecasts.
- Keep all Health data local-first.
- Give users full control over create/edit/delete/import/export of their measurements.

## 3. Non-goals for MVP

- Medical diagnosis or treatment guidance.
- Cloud accounts or sync.
- Apple Health / Health Connect integration.
- Blood pressure, blood lipids, body fat, or other Health metrics.
- Target-weight planning or deadlines.
- Push reminders to enter weight.
- Historical calorie backfill for workouts completed before the calorie feature exists.

## 4. Primary navigation

Add a top-level app destination named **Health**.

Health is intentionally broader than Weight so future health metrics can be added without renaming the navigation item.

## 5. Health Profile

Store the following profile data:

- Sex
- Birth year
- Height
- Preferred units: Metric or Imperial

Rules:

- Height is editable from profile/settings but should not occupy prominent dashboard space.
- Canonical stored weight unit is **kg**.
- Canonical stored height unit should be metric (cm); UI converts to imperial when needed.
- Profile data remains when the user chooses to delete Health measurements.

## 6. Weight measurements

A measurement is an independent event and contains:

```text
id
weightKg
timestamp
note?           // optional free text
createdAt
updatedAt
```

Requirements:

- Users may enter multiple measurements per day.
- Timestamp defaults to the current time but can be edited before or after saving.
- Users may add past measurements, e.g. measurements first written on paper.
- Users may edit and delete any measurement.
- Measurements are not locked; the user is responsible for their own data.
- Notes are optional.
- Provide quick note suggestions to avoid typing, e.g. `Morning`, `After meal`, while still allowing arbitrary text.

Entry points:

- Health screen.
- Quick action from the main AnhPT home screen.

No reminder notifications are required.

## 7. Daily aggregation

For charting, calculate the arithmetic average of all valid measurements in a calendar day in the user's local timezone.

Raw measurements must remain available and editable; daily averages are derived data and should not replace raw measurements.

## 8. Health dashboard

The Health dashboard should prioritize:

1. Current/latest weight.
2. Weight change/trend.
3. Weight chart.
4. Workout activity overlay.
5. Forecast when confidence is sufficient.
6. Secondary BMI indicator.
7. Tracking consistency feedback.

The UI should remain fast and visually simple.

### Chart scale

The chart should auto-scale to available data by default.

Users can explicitly switch between:

- Week
- Month
- Quarter
- Year

### Weight series

- Use the daily average as the displayed weight point for each day.
- Draw the real aggregated weight data; do not replace it with a smoothed trend line in the MVP.

## 9. Workout correlation

This is a key differentiator from generic weight-tracking apps.

Display workout activity on the same timeline as weight.

### Marker behavior

- A day with workout activity gets a circular workout marker.
- Aggregate all workouts in the day into one marker.
- Marker magnitude is based on total estimated calories burned that day.
- Visual treatment may use size and/or intensity/color, but should remain accessible and understandable.

### Marker interaction

When the user taps a workout/day marker, show details for that date, including:

- Daily average weight.
- Individual weight measurements for the day.
- Total estimated workout calories.
- Workout count.
- Workout/session names and relevant session details.

Use cautious language such as:

> Weight trend alongside your workout activity

Do not claim that a specific weight change was caused by exercise.

## 10. Calorie estimation

AnhPT estimates calories burned for newly completed workout sessions.

### Estimation inputs

The estimator should use, when available:

- Exercise identity/type.
- Exercise duration.
- User weight.
- User profile data where relevant.
- Exercise/workout intensity.

Use a standard, explainable exercise-energy model (e.g. MET-based estimation or equivalent evidence-based approach) rather than a fixed calorie value per workout.

### Intensity metadata

Support optional workout/exercise metadata:

```yaml
intensity: light | moderate | vigorous
```

Requirements:

- `intensity` is optional.
- Users can see intensity when choosing a workout because it helps them select an appropriate session.
- If AnhPT has a known exercise calorie profile, use that profile first.
- If an exercise cannot be classified reliably, fall back to available intensity metadata.
- If intensity is also unavailable, use a conservative default such as `moderate` and explicitly explain that the estimate is using a fallback.

Example explanation:

> Estimated from workout intensity because this exercise has no calorie profile.

### Completion UX

After a workout, show a concise result such as:

```text
Workout completed
24 min
Estimated 186 kcal burned
```

The calorie value is editable by tapping it.

- User override applies only to that completed session.
- Do not propagate the override to future workouts or exercises.
- Do not retrospectively calculate calories for old workout sessions in the MVP.

### Calculation transparency

The completion screen should stay simple, but users can tap the calorie value to view an optional breakdown explaining how the estimate was derived, including per-exercise contribution when available.

## 11. Forecast

Forecasts are intended as motivational trend estimates, not medical predictions.

Provide:

- Next-week forecast.
- Next-month forecast.
- A prediction **range**, not a single exact value.

Example:

```text
If your recent trend continues:
Next week: 71.2–71.8 kg
```

### Forecast model

Base the forecast primarily on observed weight data, not on a direct `calories burned -> kilograms lost` conversion.

Recommended MVP approach:

- Use daily average weight observations.
- Fit a recent robust linear trend/regression over an appropriate rolling window.
- Use workout calories/activity as contextual information in the UI, not as a causal term in the primary weight forecast.
- Calculate an uncertainty interval from residual variance / model uncertainty.
- Reject the forecast when uncertainty is too high or the data are too sparse.

This means a user can still show a downward weight forecast even during a week with less exercise if their measured weight trend continues downward.

### Data sufficiency and confidence gating

Do not rely only on a fixed number of elapsed days.

Suggested initial gates:

- Next-week forecast: at least 8 measurement-days spanning at least 14 days.
- Next-month forecast: at least 12 measurement-days spanning at least 21 days.

After these minimums, require model confidence to pass an uncertainty threshold. Exact thresholds should be tuned through tests and may evolve without changing the product contract.

If there is insufficient reliable data, do not predict. Instead show positive guidance such as:

> Add weight measurements regularly to unlock a more reliable forecast.

Do not send a notification.

### Safety wording

Avoid promising weight loss or encouraging excessive weight change.

Forecast copy should say that the estimate is based on the recent trend and may vary.

## 12. BMI

BMI is secondary and should not dominate the Health experience.

Calculate BMI from:

- Latest relevant weight measurement.
- Current profile height.

Display a simple range bar rather than a history chart, for example:

```text
BMI 23.6
Underweight | Healthy | Overweight | Obesity
             ^
```

Use distinct accessible range styling. Do not make color the only indicator of category.

Height changes recalculate BMI from the current/latest measurement.

## 13. Tracking consistency

Do not use punitive streak mechanics that reset to zero.

Use a softer consistency metric, for example:

> 12 measurement days in the last 14 days

This may be shown as positive feedback but must not trigger notifications.

## 14. Local-first storage

All Health data is stored locally on the device for the MVP.

No cloud account or sync is required.

Structure the persistence layer so future Health-platform sync can be added without changing the user-facing data model unnecessarily.

## 15. Import and export

Support both import and export of Health data.

Recommended formats:

- JSON for lossless backup/restore.
- CSV for portability and spreadsheet use.

Export should include source data that matters for reconstruction, such as:

- Profile.
- Weight measurements.
- Notes/timestamps.

Derived values such as daily averages, BMI, and forecasts do not need to be persisted in the export if they can be recalculated.

Workout-session data should remain owned by the workout subsystem; Health correlation can reference it rather than duplicating it.

### Units

- Store/import canonical internal weight values as kg after conversion.
- Import files containing lb values should be converted to kg.
- Display/export behavior may follow the user's selected unit while lossless JSON should clearly identify units.

### Validation

Use tolerant row/record validation:

- Valid records are imported.
- Invalid records are skipped.
- Show a clear summary of skipped rows and reasons.
- Do not reject an entire file because one row is invalid.

### Conflicts

A conflict is a record that resolves to the same logical measurement identity/timestamp according to the import strategy.

Before applying conflicts, ask the user whether to:

- **Overwrite** (default)
- **Skip**

Apply the selected policy consistently for that import operation.

## 16. Delete Health data

Provide an explicit destructive action to delete Health measurement history.

Requirements:

- Confirm before deletion.
- Delete weight measurements.
- Keep Health Profile fields such as sex, birth year, height, and unit preference.
- Derived forecasts, BMI, and daily averages disappear/recalculate automatically because their source measurements are gone.

## 17. Suggested domain model

The implementation can vary, but the product model should keep raw and derived data separate.

```text
HealthProfile
  sex
  birthYear
  heightCm
  preferredUnits

WeightMeasurement
  id
  weightKg
  timestamp
  note?
  createdAt
  updatedAt

WorkoutSessionHealthSummary
  sessionId
  completedAt
  estimatedCalories
  userOverriddenCalories?
  effectiveCalories
  estimationMethod
  estimationExplanation?

DailyHealthSummary (derived)
  localDate
  averageWeightKg?
  measurementCount
  totalWorkoutCalories
  workoutCount

WeightForecast (derived)
  generatedAt
  horizon
  predictedLowKg
  predictedHighKg
  confidence/quality metadata
  sourceWindowStart
  sourceWindowEnd
```

Do not persist derived entities unless doing so provides a concrete performance benefit.

## 18. UX flows

### First Health visit

1. Open Health.
2. Explain briefly that Health combines body trends with workout activity.
3. Ask for missing profile information needed for BMI/calorie estimates: sex, birth year, height, units.
4. Offer `Add weight` as the primary action.
5. Do not force the user to complete optional data unrelated to the first measurement.

### Add weight

1. Tap Add weight from Health or home quick action.
2. Weight input is focused immediately.
3. Timestamp defaults to now.
4. Optional timestamp edit.
5. Optional note or suggested note chip.
6. Save.
7. Return immediately to updated Health dashboard.

### Edit/delete measurement

1. Open a measurement/day detail.
2. Edit weight, timestamp, or note; or choose Delete.
3. Save/delete.
4. Recalculate affected daily averages, BMI, trend, and forecast.

### Workout completion

1. Complete workout.
2. Show estimated calories.
3. User may tap to inspect calculation or override the session value.
4. Health chart automatically reflects that day's effective calorie total.

## 19. Acceptance criteria for MVP

### Weight capture

- A user can create multiple weight measurements on the same day.
- Each measurement has an editable timestamp.
- A user can enter a past timestamp.
- A user can add optional notes and use suggested note chips.
- A user can edit/delete existing measurements.

### Units/profile

- User can select metric or imperial display units.
- Weight is stored canonically in kg.
- Height/profile fields are editable.

### Dashboard/chart

- Chart uses daily average weight.
- Week/Month/Quarter/Year views work.
- Chart displays workout markers for days with workouts.
- Marker magnitude represents total effective estimated calories for the day.
- Tapping a marker opens date-level detail.

### Calories

- New workout completion shows estimated calories.
- Estimate uses exercise information where available.
- Unknown exercises can fall back to intensity.
- Fallback estimation is explained to the user.
- User can override calories for that session only.
- User can inspect an estimation breakdown.

### Forecast

- Forecasts show ranges for next week/month only when data and confidence are sufficient.
- Insufficient data never produces a numerical forecast.
- Missing forecast state encourages regular measurement without sending reminders.

### BMI

- Latest BMI is calculated from current height and latest weight.
- BMI is shown as a categorized range bar, not a history chart.

### Data ownership

- Health data remains local.
- User can export and import Health data.
- Import converts supported units to canonical kg.
- Import skips invalid records and reports them.
- Import conflicts prompt for Overwrite or Skip; Overwrite is the default choice.
- Delete Health data removes measurements but preserves Health Profile.

## 20. Edge cases

- Multiple weight measurements with identical timestamps.
- Timezone/DST changes around midnight.
- User changes unit settings after years of data.
- User changes height after BMI was previously displayed.
- Extremely sparse weight measurements.
- Large short-term weight fluctuations.
- Missing workout-calorie estimates.
- Workout session is deleted after Health chart previously referenced it.
- Imported file has mixed units, malformed timestamps, duplicate records, or partial corruption.
- Forecast trend is flat, increasing, decreasing, or highly noisy.
- User has workouts but no weight measurements, or weight measurements but no workouts.

## 21. Testing considerations

Include tests for:

- kg/lb and cm/ft-in conversions.
- Daily averages with multiple entries/day.
- Local timezone and DST day grouping.
- CRUD recalculation behavior.
- Calorie fallback hierarchy.
- Session-only override behavior.
- Import validation/conflict handling.
- Forecast confidence gating and uncertainty ranges.
- No numerical forecast for insufficient/noisy data.
- BMI boundary values.
- Empty-state and delete-all-measurements flows.

## 22. Later phases

Potential future work, explicitly outside this MVP:

- Apple Health / Health Connect import and sync.
- Blood pressure.
- Blood lipids.
- Body fat/body composition.
- Additional body measurements.
- Cross-metric trends.
- Nutrition data.
- Cloud backup/sync.
- More sophisticated personalized exercise-energy estimation.
- Optional goals and target dates.

Any future health interpretation should continue to distinguish correlation from causation and avoid presenting AnhPT as a medical diagnostic product.
