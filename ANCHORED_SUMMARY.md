## Goal
Fix driver profile photo upload (gallery → storage), persist manager user edits to Supabase, propagate driver profile changes to homescreen, complete all Reports analytics fixes, and replace app icon + splash screen branding.

## Constraints & Preferences
- Use `PhotosPicker` for photo selection across the app (not URL text field).
- Raw `URLSession` `PUT` with raw bytes for Supabase Storage upload (no multipart, bypass SDK response parsing).
- Manager user edit must update both local `users` array and Supabase row — use the server-returned user.
- Driver profile update must refresh `DriverDashboardView` user data on navigation pop.
- App icon images from `AppIcons/` in project root → copy into project's `AppIcon.appiconset`.
- Splash screen logo replaces `car.2.fill` SF Symbol with the app icon image.
- All changes on `fix/Trip-cancellation-pre-post-&-UI`, build with zero errors.

## Progress
### Done
- **Reports analytics fixed**: `MaintenanceTaskStatus.isOpen` helper added, `PeriodPreset` redesigned (2M/4M/8M/1Y with `monthStarts` + clamped `dateRange`), `MaintenanceTaskPart` gained `quantity`/`unitPrice` with robust decoder, `filteredTripsByMonth`/`fleetUtilizationByMonth` iterate `monthStarts` and clamp last bucket to `Date()`, `currentMonthRange` uses actual month-start, `chartXScale` domain constraints added.
- **Photo upload from gallery**: `ProfileHubView` reverted to `PhotosPicker` with `selectedItem`/`profileImageData`. `DriverProfileViewModel` rewritten: `updateProfile` accepts `newProfileImageData: Data?`, `uploadProfileImage` uses **raw `URLSession` `PUT`** with raw JPEG bytes (no multipart), `cache-control: 3600`, `x-upsert: true`, JPEG compression at 0.82.
- **Driver profile → homescreen**: `DriverDashboardView.user` changed from `let` to `@State` via custom init, `.onChange(of: showingProfile)` calls `reloadCurrentUser()` (fetch all users + filter).
- **Manager edit persistence**: `UserManagementViewModel.updateUser` stores server-returned user (`users[index] = updated`). Service's `updateUser` already includes `avatarurl` in the update dict.
- **App icon**: 20 PNGs from `AppIcons/Assets.xcassets/AppIcon.appiconset/` copied into project's `Resources/Assets.xcassets/AppIcon.appiconset/` — ready for Xcode build.
- **Splash branding**: `SplashLogo.imageset` created in `Assets.xcassets` using the 1024×1024 icon PNG. `SplashView` updated: `Image("car.2.fill")` → `Image("SplashLogo")` with `resizable`/`aspectRatio`/rounded clip.

### In Progress / Blocked
- (none)

## Key Decisions
- **Upload format**: Raw bytes `PUT` to `{supabaseURL}/storage/v1/object/{bucket}/{path}` with `Content-Type: image/jpeg`, `x-upsert: true`, `cache-control: 3600`. No multipart. This matches Supabase Storage simple upload API exactly.
- **Splash image**: Uses the same 1024×1024 icon PNG from the asset catalog, displayed at 120×120 with 24pt corner radius in the splash screen.
- **No SDK upload**: `supabase-swift`'s `storage.upload()` decodes `UploadResponse { Key, Id }` which fails ("cannot parse response") — raw `URLSession` bypasses this entirely.

## Next Steps
1. Open project in Xcode, build and run.
2. Verify app icon appears on home screen (may need to re-install).
3. Test photo upload: select photo → save → confirm image shows in profile header → check Supabase Storage bucket `maintenance` for the uploaded file.
4. Verify splash screen shows the app icon logo instead of the two-car SF Symbol.

## Critical Context
- Supabase bucket `maintenance` is public with public INSERT/ALL policies.
- `UserManagementService.updateUser` at line 40 includes `"avatarurl"` in the update dict — the DB path works.
- `AppIcon.appiconset/` is inside `Resources/Assets.xcassets/` — Xcode picks it up automatically.
- Branch: `fix/Trip-cancellation-pre-post-&-UI`

## Files Changed
- `FMS/Modules/Driver/Features/Profile/ProfileHubView.swift`: PhotosPicker restored, selectedItem/profileImageData, EditProfileView uses gallery.
- `FMS/Modules/Driver/Features/Profile/DriverProfileViewModel.swift`: profileImageData, updateProfile(newProfileImageData:), raw bytes `PUT` upload, JPEG compression.
- `FMS/Modules/Driver/Views/DriverDashboardView.swift`: let user → @State var user via init, onChange(of: showingProfile) triggers reloadCurrentUser().
- `FMS/Modules/FleetManager/ViewModels/UserManagementViewModel.swift`: updateUser stores server-returned user.
- `FMS/Modules/Auth/Views/SplashView.swift`: `Image("car.2.fill")` → `Image("SplashLogo")`.
- `FMS/Resources/Assets.xcassets/SplashLogo.imageset/`: New image set with 1024.png.
- `FMS/Resources/Assets.xcassets/AppIcon.appiconset/`: 20 PNGs + Contents.json copied from AppIcons.
