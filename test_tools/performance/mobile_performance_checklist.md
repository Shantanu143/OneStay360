# OneStay360 Mobile Performance Testing Checklist

## App Startup Performance

### Business App
- [ ] Cold start time < 3 seconds on mid-range device (Redmi Note 10)
- [ ] Warm start time < 1.5 seconds
- [ ] Firebase initialization < 500ms
- [ ] App Check initialization < 300ms
- [ ] First meaningful paint < 2 seconds

### Tenant App
- [ ] Cold start time < 3 seconds
- [ ] Warm start time < 1.5 seconds
- [ ] Explore screen loads within 2 seconds
- [ ] Property images load progressively (cached_network_image)

## Screen Transition Performance
- [ ] All screen transitions at 60fps (no jank)
- [ ] Bottom navigation switching < 100ms
- [ ] Modal/dialog animations smooth
- [ ] List scrolling smooth (RecyclerView equivalent)

## Network Performance
- [ ] Firestore reads < 500ms (cached)
- [ ] Firestore reads < 2s (uncached)
- [ ] Cloud Function calls < 3s (95th percentile)
- [ ] Image uploads < 5s for 2MB image
- [ ] Offline mode graceful degradation

## Memory Usage
- [ ] Business app < 150MB RAM on mid-range device
- [ ] Tenant app < 120MB RAM on mid-range device
- [ ] No memory leaks in StreamBuilders
- [ ] Provider disposal working correctly
- [ ] Image cache bounded (cached_network_image)

## Battery Usage
- [ ] Background FCM handling minimal battery drain
- [ ] No unnecessary polling or wake locks
- [ ] Location services not used unnecessarily

## Firebase Performance Metrics
Run these in Firebase Console → Performance Monitoring:

### Custom Traces to Add
```dart
// Add to critical operations
final trace = FirebasePerformance.instance.newTrace('enrollment_approval');
await trace.start();
// ... operation ...
await trace.stop();
```

Traces to implement:
- [ ] `enrollment_approval` - Time to approve enrollment
- [ ] `payment_submission` - Time to submit payment
- [ ] `invoice_generation` - Time to generate invoice
- [ ] `dashboard_load` - Time to load dashboard metrics
- [ ] `property_list_load` - Time to load property list
- [ ] `tenant_list_load` - Time to load tenant list

## Firestore Query Performance

### Indexes Required (firestore.indexes.json)
Verify these composite indexes exist:
- [ ] `enrollmentRequests`: businessId + status + createdAt
- [ ] `businesses/{id}/tenants`: status + createdAt
- [ ] `businesses/{id}/tenants/{id}/payments`: status + createdAt
- [ ] `businesses/{id}/tenants/{id}/rent_invoices`: status + dueDate
- [ ] `businesses/{id}/audit_logs`: createdAt (desc)

### Query Optimization
- [ ] All queries use indexed fields
- [ ] Pagination implemented for large lists
- [ ] `limit()` applied to all queries
- [ ] `collectionGroup` queries have proper indexes

## Testing Tools

### Flutter Performance Profiling
```bash
# Run with performance overlay
flutter run --profile

# Generate performance trace
flutter run --trace-startup --profile

# Check for jank
flutter run --profile --trace-skia
```

### Firebase Test Lab
```bash
# Run on real devices
gcloud firebase test android run \
  --type instrumentation \
  --app apps/business/build/app/outputs/apk/debug/app-debug.apk \
  --test apps/business/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
  --device model=Pixel4,version=30,locale=en,orientation=portrait \
  --device model=OnePlus6T,version=28,locale=en,orientation=portrait
```

### Load Testing
```bash
# Install Artillery
npm install -g artillery

# Run load test
npx artillery run test_tools/performance/load_test.yml

# Generate HTML report
npx artillery run --output report.json load_test.yml
npx artillery report report.json
```

## Performance Benchmarks

| Metric | Target | Critical |
|--------|--------|----------|
| App cold start | < 3s | < 5s |
| Screen transition | < 300ms | < 500ms |
| Firestore read (cached) | < 200ms | < 500ms |
| Firestore read (network) | < 1s | < 2s |
| Cloud Function call | < 2s | < 5s |
| Image load (cached) | < 100ms | < 300ms |
| Image load (network) | < 2s | < 5s |
| Memory usage | < 150MB | < 250MB |
| API error rate | < 0.1% | < 1% |
