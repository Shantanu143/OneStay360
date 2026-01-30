# Simplified Enrollment Dialog - User Experience

## Dialog Layout

```
┌─────────────────────────────────────────┐
│         Confirm Request                 │
├─────────────────────────────────────────┤
│                                         │
│  Property Name (Bold)                   │
│  Property Address (Gray, 2 lines max)   │
│                                         │
│  Move-in Date *                         │
│  [📅 DD/MM/YYYY or "Select date"]       │
│                                         │
│  Room Type                              │
│  [▼ Choose room type]                   │
│     - Private                           │
│     - Shared                            │
│                                         │
│  Sharing Preference                     │
│  [▼ Choose sharing option]              │
│     - Single                            │
│     - Double                            │
│     - Triple                            │
│                                         │
│  Additional Notes                       │
│  [Text area - multi-line]               │
│   Any special requests...               │
│                                         │
├─────────────────────────────────────────┤
│        [Cancel]  [🔄 Send Request]     │
└─────────────────────────────────────────┘
```

## Field Specifications

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| Move-in Date | Date Picker | ✅ Yes | Today+1day | Enforced validation |
| Room Type | Dropdown | ❌ No | Unselected | 2 options |
| Sharing Preference | Dropdown | ❌ No | Unselected | 3 options |
| Notes | Text Area | ❌ No | Empty | 2-3 lines visible |

## Tenant Data (Pre-filled, not shown)
- **Name**: From `/tenants/{tenantId}.name`
- **Phone**: From `/tenants/{tenantId}.phone`

## Loading State
- Button shows spinner when submitting
- Button disabled during submission
- Dialog stays open until success/error

## Success Feedback
```
✅ "Request sent successfully! 🎉"
(Green snackbar, 3 seconds, then dialog closes)
```

## Error Feedback
```
❌ [Error message from submission]
(Red snackbar, clickable to dismiss)
```

## Edge Cases Handled

1. **Move-in date not selected**
   - Validation error snackbar
   - Form stays open

2. **Tenant data missing**
   - Error snackbar: "Failed to load tenant data"
   - Form stays open for retry

3. **Firestore submission fails**
   - Error snackbar with specific error message
   - User can retry

4. **Network timeout**
   - Handled by repository error handling
   - User sees timeout error message

## Performance Notes

- Dialog uses `StatefulBuilder` for internal state management
- `Consumer<PGDetailViewModel>` listens only to submission state
- Text controllers disposed properly to prevent memory leaks
- No page navigation - better performance on slower devices
