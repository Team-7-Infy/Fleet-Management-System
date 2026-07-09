# Fleet Management System (FMS) — Refined Software Requirements Specification

**Version:** 3.3
**Date:** July 2, 2026
**Platform:** iOS 18+ (iPhone + iPad)
**Architecture:** SwiftUI + MVVM + Swift Concurrency
**Backend:** Supabase (PostgreSQL, Auth, Realtime, RLS)

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Business Model & Multi-Tenancy](#2-business-model--multi-tenancy)
3. [User Roles & Permissions](#3-user-roles--permissions)
4. [Technical Stack](#4-technical-stack)
5. [Functional Requirements by Module](#5-functional-requirements-by-module)
   - 5.1 Authentication & User Management
   - 5.2 Vehicle Management & Compliance
   - 5.3 Trip Management
   - 5.4 Route Corridor Geofencing
   - 5.5 GPS Tracking & Telemetry
   - 5.6 Vehicle Inspections
   - 5.7 Maintenance Management
   - 5.8 Work Order Management
   - 5.9 Inventory Management & Purchasing
   - 5.10 Driver Scoring
   - 5.11 Vehicle Health Scoring
   - 5.12 Fleet Utilization
   - 5.13 Dashboard
   - 5.14 Reporting & Exports
   - 5.15 Notifications
   - 5.16 Draft Recovery
6. [Non-Functional Requirements](#6-non-functional-requirements)
7. [Data Retention Policy](#7-data-retention-policy)
8. [Glossary](#8-glossary)

---

## 1. Product Vision

A multi-tenant SaaS Fleet Management System that enables fleet managers, drivers, and maintenance personnel to efficiently manage vehicle fleets, track trips, schedule maintenance, control costs, and monitor operational performance through an iOS application.

The system is designed to operate generically across different fleet-based organizations without requiring per-company customization or white-labeling.

---

## 2. Business Model & Multi-Tenancy

| Aspect | Decision |
|--------|----------|
| **Deployment** | Multi-tenant SaaS — single hosted instance, isolated data per company |
| **White-labeling** | Not supported in MVP |
| **Company branding** | Company name and logo only (configurable per tenant) |
| **Custom fields** | Not supported — fixed schema shared across all tenants |
| **Onboarding** | Platform admin creates Fleet Manager account → Fleet Manager invites users |

---

## 3. User Roles & Permissions

Each user has exactly one role. No hybrid roles.

| Role | Count | Responsibilities |
|------|-------|------------------|
| **Fleet Manager** | 1+ per tenant | User management, vehicle CRUD, trip creation & assignment, maintenance oversight, inventory management, purchase orders, dashboard, reports |
| **Driver** | N per tenant | Accept/reject trips, start/end trips, pre/post trip vehicle inspection, GPS tracking, voice logging, defect reporting, route navigation via Apple Maps |
| **Maintenance Personnel** | N per tenant | View/update work orders, record parts usage & labour, complete & verify work orders |

**Platform Admin** (non-app role): Creates Fleet Manager accounts at onboarding. Not an app user — exists only in backend.

---

## 4. Technical Stack

| Layer | Technology |
|-------|-----------|
| **iOS App** | SwiftUI, iOS 18+ |
| **Architecture** | MVVM with Swift Concurrency (async/await, actors) |
| **Backend** | Supabase (PostgreSQL 15+) |
| **Auth** | Supabase Auth — email + password + OTP on every login; separate OTP flow for forgot-password and password reset |
| **Realtime** | Supabase Realtime (broadcast + presence) |
| **Authorization** | Row Level Security (RLS) — role-based policies per table |
| **Navigation** | Apple Maps (driver only, via URL launch) |
| **Geofencing** | MapKit route corridor — sampled circular regions along optimized route |
| **Tracking** | Core Location (adaptive frequency) |
| **Localization** | English only (architecture supports future localization) |
| **Passkeys / SSO / OAuth** | Not supported |

### What Is Explicitly Out of Scope

- iMessage Business Chat
- ERP / accounting / payment gateway integrations
- Full offline mode / offline sync engine
- Intermediate stops / multi-leg trips
- ML/AI models (all scoring is rule-based; OCR uses Apple Vision framework)
- Supplier integration for purchase orders (POs are managed manually)

---

## 5. Functional Requirements by Module

### 5.1 Authentication & User Management

#### 5.1.1 Authentication

| ID | Requirement | Role |
|----|-------------|------|
| AUTH-01 | User logs in every time with email + password + OTP via Supabase Auth | All |
| AUTH-02 | User requests password reset — receives OTP via email | All |
| AUTH-03 | User resets password using OTP verification | All |
| AUTH-04 | Session is persisted across app launches (Supabase session management) | All |
| AUTH-05 | User signs out, clearing local session | All |
| AUTH-06 | No public registration — accounts are invite-only | System |

#### 5.1.2 User Management (Fleet Manager)

| ID | Requirement | Role |
|----|-------------|------|
| UM-01 | View list of all users (drivers, maintenance personnel) with status of employment in organization (on leave/on duty) | Fleet Manager |
| UM-02 | Create a new user account (email, name, role, phone) — system generates a temporary password and sends an invite email | Fleet Manager / System |
| UM-03 | Edit user profile (name, phone, status) | Fleet Manager |
| UM-04 | Archive (soft-delete) a user — prevents login, preserves history | Fleet Manager |
| UM-05 | View driver-specific details: UID, name, email, license number, license class, license expiry, joining date, driver score, Aadhaar (masked — displayed as XXXX-XXXX-1234), profile photo, authorized vehicle type(s) | Fleet Manager |
| UM-06 | View maintenance personnel details: UID, joining date, name, email, Aadhaar (masked — displayed as XXXX-XXXX-1234), address, profile photo | Fleet Manager |

#### 5.1.3 User Self-Service

| ID | Requirement | Role |
|----|-------------|------|
| US-01 | View own profile | All |
| US-02 | Update own profile (name, phone, photo, authorized vehicle types for drivers) | All |
| US-03 | Change password | All |

#### 5.1.4 First-Time Onboarding & Profile Completion

**Applies to:** Driver and Maintenance Personnel only. Fleet Manager accounts are created by Platform Admin and do not go through this flow.

| ID | Requirement | Role |
|----|-------------|------|
| ONB-01 | Fleet Manager creates a Driver or Maintenance Personnel account via UM-02 — the system generates a temporary password and sends an invite email with login instructions | Fleet Manager / System |
| ONB-02 | Invited user logs in with the temporary password on their first launch | Driver, Maintenance Personnel |
| ONB-03 | System forces a password reset immediately after the first successful login — the user cannot proceed until a new password is set | System |
| ONB-04 | After password reset, the user is routed to a mandatory role-specific profile completion form. The screen cannot be dismissed, skipped, or navigated away from (signing out is the only exit) | System |
| ONB-05 | Driver profile requires: driving license number, driving license class (multi-select: LMV, HMV — a license can hold both), license expiry date, Aadhaar number (see ONB-11), profile photo, one or more authorized vehicle types from `{van, car, truck, bus}` | Driver |
| ONB-06 | Maintenance Personnel profile requires: Aadhaar number (see ONB-11), address, profile photo | Maintenance Personnel |
| ONB-07 | Until the profile form is submitted, the user has zero access beyond the form — no dashboard, cannot be assigned trips or work orders | System |
| ONB-08 | On submission, the profile is marked complete immediately. No Fleet Manager review or approval — data is self-attested | System |
| ONB-09 | Once complete, the user is routed to their role-specific dashboard (see 5.13) | System |
| ONB-10 | Driver's authorized vehicle type(s) act as a hard filter in trip auto-assignment (see TRP-02). A driver is eligible only if the trip's vehicle type is in their authorized list | System |
| ONB-11 | Driver and Maintenance Personnel enter their full 12-digit Aadhaar number on the profile form. The app validates it is exactly 12 digits before submission | Driver, Maintenance Personnel |
| ONB-12 | System stores only the last 4 digits of the Aadhaar number. The full number is never persisted to the database or written to any log | System |
| ONB-13 | Fleet Manager-facing views (UM-05, UM-06) display Aadhaar as `XXXX-XXXX-1234` — last 4 digits only, never the full number | System |
| ONB-14 | After profile completion, users can edit their profile (including authorized vehicle types) via the self-service screen (US-02) — same self-attested model, no re-approval required | Driver, Maintenance Personnel |
| ONB-15 | Vehicle-type options on the Driver profile form are dynamically filtered by the selected DL class: LMV only → `car`, `van` selectable, `truck` and `bus` hidden/disabled; HMV present → `truck` and `bus` also selectable | System |
| ONB-16 | The same dynamic filtering applies on profile edit — a driver cannot select a vehicle type their current DL class does not cover | System |

---

### 5.2 Vehicle Management & Compliance

#### 5.2.1 Vehicle CRUD

| ID | Requirement | Role |
|----|-------------|------|
| VEH-01 | Add a new vehicle (VIN, license plate, make, model, year, vehicle type `{van, car, truck, bus}`, fuel type `{petrol, diesel, CNG}`, regular maintenance time interval, regular maintenance kilometer interval) | Fleet Manager |
| VEH-02 | Edit vehicle information | Fleet Manager |
| VEH-03 | Archive a vehicle (soft-delete — preserves history) | Fleet Manager |
| VEH-04 | View vehicle list with filtering (status, type) and search | Fleet Manager |
| VEH-05 | View vehicle detail: info, compliance docs, maintenance history, trip history, health score | Fleet Manager |
| VEH-06 | View assigned vehicle's basic info (driver-side) | Driver |
| VEH-07 | View vehicle info for work order context | Maintenance Personnel |
| VEH-08 | Vehicle statuses: `available`, `assigned`, `in_maintenance`, `out_of_service` | System |
| VEH-09 | Fleet Manager can manually set a vehicle to `out_of_service` | Fleet Manager |

#### 5.2.2 Vehicle Compliance Tracking

| ID | Requirement | Role |
|----|-------------|------|
| COM-01 | Add/edit compliance documents per vehicle: insurance, registration, road tax, permit, pollution under control | Fleet Manager |
| COM-02 | Each document has: type, document number, issue date, expiry date, file attachment | Fleet Manager |
| COM-03 | System auto-calculates status: `valid`, `expiring_soon` (<30 days), `expired` | System |
| COM-04 | Compliance expiry generates a notification to Fleet Manager | System |

#### 5.2.3 Driver Compliance

| ID | Requirement | Role |
|----|-------------|------|
| DCOM-01 | System tracks license expiry and notifies Fleet Manager | System |

---

### 5.3 Trip Management

#### 5.3.1 Trip Creation & Assignment

**Assignment Algorithm (used by TRP-02 and TRP-08):** Hard filter — candidate driver's authorized vehicle type(s) must include the trip's vehicle type. Among eligible drivers, rank by proximity to trip start point, availability, schedule fit, and driver score.

| ID | Requirement | Role |
|----|-------------|------|
| TRP-01 | Create a trip with: origin (MapKit-integrated search), destination (MapKit-integrated search), vehicle selection | Fleet Manager |
| TRP-02 | Trip automatically assigns the best eligible driver based on the assignment algorithm | System |
| TRP-03 | Fleet Manager can manually override the auto-assigned driver | Fleet Manager |
| TRP-04 | Trip statuses: `rejected`, `in_progress`, `completed`, `cancelled` | System |
| TRP-05 | Trip always has exactly one origin and one destination — no intermediate stops | System |

#### 5.3.2 Driver Trip Flow

| ID | Requirement | Role |
|----|-------------|------|
| TRP-06 | Driver views assigned trip(s) with origin, destination, ETA | Driver |
| TRP-07 | Driver is assigned to a trip and rejects a trip if they have a reason | Driver |
| TRP-08 | If rejected, driver submits a reason; system re-assigns using the same assignment algorithm as TRP-02 | System |
| TRP-09 | Driver starts the trip — begins GPS tracking, sets `expected start time` | Driver |
| TRP-10 | During trip: show origin, destination, current location, live ETA, elapsed time | Driver |
| TRP-11 | Driver completes the trip on arrival — records `actual end time`, `actual start time`, distance | Driver |
| TRP-12 | After completion: trip summary shows expected vs actual start time, actual end time, distance, driver remarks | Driver |

#### 5.3.3 Voice-Based Trip Logging

| ID | Requirement | Role |
|----|-------------|------|
| VTL-01 | Driver can record voice notes during a trip (speech-to-text) | Driver |
| VTL-02 | Voice capture available for: trip remarks, delay reports, general notes, road closures, route changes, accidents, weather issues, start-trip note, stop-trip completion note | Driver |
| VTL-03 | Converted text is stored with the trip record | System |
| VTL-04 | Voice notes support draft recovery if interrupted | System |

#### 5.3.4 Trip Monitoring (Fleet Manager)

| ID | Requirement | Role |
|----|-------------|------|
| TRP-13 | View all trips with filtering (status, driver, vehicle, date range) | Fleet Manager |
| TRP-14 | View live trip progress: current location, ETA, route adherence status | Fleet Manager |
| TRP-15 | View list of rejected trips with driver-submitted reasons | Fleet Manager |
| TRP-16 | Manually override driver assignment on pending trips | Fleet Manager |
| TRP-17 | All voice transcriptions, receipt OCR data, and fuel entries are compiled into the trip's permanent record | System |
| TRP-18 | Fleet Manager views the complete trip report including: trip summary (times, distance), route deviation log, inspection results, expense entries (fuel + toll/OCR), and defect reports | Fleet Manager |
| TRP-19 | Fleet Manager can browse past trip reports from the trip history — selecting a trip card shows a summary, tapping navigates to full trip details | Fleet Manager |

#### 5.3.5 Trip Expenses — Fuel Entries

| ID | Requirement | Role |
|----|-------------|------|
| FEL-01 | Driver logs a fuel entry: liters, cost per liter, total cost (may be pre-filled via receipt OCR per TOL-09, or entered manually), fuel type `{petrol, diesel, CNG}`, odometer reading | Driver |
| FEL-02 | Fuel entry can be linked to a trip (optional) | Driver |
| FEL-03 | Fuel entry records: location (GPS), timestamp | System |
| FEL-04 | Fuel entries feed into reports and cost tracking | System |
| FEL-05 | Fleet Manager views fuel entries per vehicle, driver, date range | Fleet Manager |
| FEL-06 | Fuel entry auto-links to the active trip if one exists at the time of logging. Stays optional/unlinked only if no trip is active | System |

#### 5.3.6 Trip Expenses — Toll Entries (Vision OCR)

| ID | Requirement | Role |
|----|-------------|------|
| TOL-01 | Driver selects receipt type from a picker (fuel, toll, parking, permit, other) before uploading | Driver |
| TOL-02 | Driver captures a receipt photo using camera or photo library | Driver |
| TOL-03 | System processes the image using Apple Vision framework's text recognition (OCR) | System |
| TOL-04 | OCR extracts: amount, date, receipt number, vendor name | System |
| TOL-05 | Driver reviews and edits extracted fields before saving | Driver |
| TOL-06 | Toll entry is linked to the active trip | System |
| TOL-07 | Fleet Manager views all expense entries (fuel, toll, parking, permit, other) per trip, driver, vehicle | Fleet Manager |
| TOL-08 | Original receipt image is stored with the entry for audit | System |
| TOL-09 | When receipt type is `fuel`, the OCR-extracted amount maps to the fuel entry's total cost (FEL-01). The driver still manually enters liters, cost per liter, fuel type, and odometer reading — OCR cannot read those from a receipt | System |

---

### 5.4 Route Corridor Geofencing

| ID | Requirement | Role |
|----|-------------|------|
| GEOF-01 | When a trip is created, system computes an optimized route from origin to destination using MapKit | System |
| GEOF-02 | System samples points along the route polyline and creates overlapping circular geofence regions (route corridor) | System |
| GEOF-03 | Driver's live GPS is continuously compared against the route corridor | System |
| GEOF-04 | Deviation severity levels: `<50m` = Normal, `50–150m` = Minor, `150–500m` = Major, `>500m` = Critical | System |
| GEOF-05 | Route deviation generates notifications to both driver and fleet manager | System |
| GEOF-06 | Route adherence history is used in driver score calculation | System |

---

### 5.5 GPS Tracking & Telemetry

| ID | Requirement | Role |
|----|-------------|------|
| GPS-01 | GPS tracking activates when a driver starts a trip | System |
| GPS-02 | GPS tracking stops when a trip is completed or cancelled | System |
| GPS-03 | No GPS tracking outside active trips — no continuous surveillance | System |
| GPS-04 | Location update frequency is adaptive: higher frequency while moving, reduced when stationary | System |
| GPS-05 | Telemetry records: latitude, longitude, speed, heading, timestamp | System |
| GPS-06 | GPS data is buffered locally if connection is lost and uploaded when connectivity resumes | System |

---

### 5.6 Vehicle Inspections

#### 5.6.1 Pre-Trip Inspection

| ID | Requirement | Role |
|----|-------------|------|
| INS-01 | Driver performs a pre-trip inspection before starting a trip | Driver |
| INS-02 | Inspection checklist includes categories: tires, lights, brakes, fluids, mirrors, windshield, horn, seatbelts, fuel level | System |
| INS-03 | Each checklist item: `pass`, `fail` | Driver |
| INS-04 | At least one photo required if any item is marked `fail` | Driver |
| INS-05 | Optional notes per item | Driver |
| INS-06 | If any item fails, a work order is auto-created for Maintenance Personnel to accept or reject on the basis of legitimacy after diagnosing the vehicle for the reported defect. If an invalid defect is reported by the driver, the driver's score is reduced | System |
| INS-07 | Driver cannot start the trip until inspection is completed (all items reviewed) | System |
| INS-08 | When pre-trip inspection fails (see INS-06), the system searches available vehicles as replacement candidates. The trip proceeds only once a replacement vehicle passes its own pre-trip inspection, or is blocked pending Fleet Manager intervention if no replacement exists | System |
| INS-09 | Replacement candidates are filtered to vehicle types the driver is authorized for (see ONB-10) | System |
| INS-10 | Among eligible replacement candidates, the system selects the one with the highest vehicle health score (VHS-01) | System |
| INS-11 | The original vehicle is set to `in_maintenance`, linked to the auto-created work order (INS-06); the trip's vehicle assignment is updated to the replacement | System |
| INS-12 | The driver must complete a fresh pre-trip inspection on the replacement vehicle before the trip can start — the failed inspection does not carry over | System |
| INS-13 | If no eligible replacement exists, the trip cannot start; Fleet Manager is notified for manual intervention | System |

#### 5.6.2 Post-Trip Inspection

| ID | Requirement | Role |
|----|-------------|------|
| INS-14 | Driver performs a post-trip inspection after completing a trip | Driver |
| INS-15 | Same checklist structure as pre-trip | Driver |
| INS-16 | Any failures → defect report auto-created | System |
| INS-17 | Post-trip inspection must be completed within the app before the trip is fully closed | System |

#### 5.6.3 Inspection History

| ID | Requirement | Role |
|----|-------------|------|
| INS-18 | Fleet Manager views inspection history per vehicle with pass/fail summary | Fleet Manager |
| INS-19 | Inspection history feeds into vehicle health score | System |

---

### 5.7 Maintenance Management

#### 5.7.1 Maintenance Scheduling

| ID | Requirement | Role |
|----|-------------|------|
| MNT-01 | Configure maintenance cycles per vehicle at onboarding: **time-based** (e.g., every 6 months) AND **mileage-based** (e.g., every 5,000 km) | Fleet Manager |
| MNT-02 | Both cycles run independently — vehicle is due when **either** threshold is reached | System |
| MNT-03 | Maintenance schedule tracks: task type through the description provided, interval (km/days), last completed km, last completed date | System |
| MNT-04 | System auto-generates notification when vehicle becomes maintenance-due | System |
| MNT-05 | Fleet Manager can view all scheduled maintenance across the fleet | Fleet Manager |

#### 5.7.2 Mid-Trip Defect → Work Order Flow

| ID | Requirement | Role |
|----|-------------|------|
| MNT-06 | Driver reports a vehicle defect (title, description) during or after a trip | Driver |
| MNT-07 | Maintenance Personnel reviews the defect report and approves or rejects + reports it | Maintenance Personnel |
| MNT-08 | If approved, a Critical work order is automatically created | System |
| MNT-09 | Maintenance Personnel view, repair, complete, and verify the work order | Maintenance Personnel |
| MNT-10 | System tracks the full chain: defect → approval → work order → repair → verification | System |
| MNT-11 | System increments a per-driver legitimate/false defect-report counter each time Maintenance Personnel approves or rejects a defect report (MNT-07) | System |

---

### 5.8 Work Order Management

| ID | Requirement | Role |
|----|-------------|------|
| WO-01 | Lifecycle: `created` → `assigned` → `in_progress` → `completed` → `verified` → `closed` | System |
| WO-02 | Fleet Manager views work orders (scheduled or ad-hoc) | Fleet Manager |
| WO-03 | System assigns work orders to maintenance personnel | System |
| WO-04 | Fleet Manager can toggle **critical** flag on any work order (highest priority) | Fleet Manager |
| WO-05 | Maintenance Personnel views assigned work orders, sorted by priority | Maintenance Personnel |
| WO-06 | Maintenance Personnel sets work order status: `in_progress`, `completed` | Maintenance Personnel |
| WO-07 | On completion: record parts used (from inventory), quantity, labour cost, parts cost, optional remarks | Maintenance Personnel |
| WO-08 | Fleet Manager can view all work orders with filtering (status, priority, vehicle, date) | Fleet Manager |
| WO-09 | System records a timestamp at each work order status transition: `assigned`, `in_progress`, `completed`, `verified`, `closed` | System |
| WO-10 | Labour hours for a work order = timestamp(`completed`) − timestamp(`in_progress`) — actual time spent working, excluding time the order sat queued before the Maintenance Personnel started | System |

---

### 5.9 Inventory Management & Purchasing

#### 5.9.1 Inventory Management

| ID | Requirement | Role |
|----|-------------|------|
| INV-01 | Fleet Manager uploads a CSV file to bulk-add inventory items (name, SKU, description, category, unit, quantity, reorder level, unit cost) | Fleet Manager |
| INV-02 | CSV format: header row with columns `name, sku, description, category, unit, quantityOnHand, reorderLevel, unitCost`. System validates the CSV and rejects rows with missing/invalid data, returning error details. On success, all rows are inserted into the inventory table in a single batch | System |
| INV-03 | Fleet Manager edits inventory item details | Fleet Manager |
| INV-04 | Inventory is automatically reduced when maintenance personnel consume parts in a work order | System |
| INV-05 | Fleet Manager views inventory list (accessible from list items in profile view) with search, filter by category, low-stock items | Fleet Manager |
| INV-06 | Maintenance Personnel views inventory (read/consume-only) during work order completion | Maintenance Personnel |

#### 5.9.2 Inventory Threshold & Purchase Orders

| ID | Requirement | Role |
|----|-------------|------|
| INV-07 | Fleet Manager sets reorder level per inventory item | Fleet Manager |
| INV-08 | When `quantityOnHand ≤ reorderLevel`, system generates a low-stock notification to Fleet Manager | System |
| INV-09 | Notification includes: item name, remaining quantity, **"Download Quotation"** action | System |
| INV-10 | Fleet Manager can create Purchase Orders manually | Fleet Manager |
| INV-11 | Purchase Order is managed manually — no automated supplier or ERP integration | Fleet Manager |
| INV-12 | No supplier, vendor, or procurement workflow | System |

---

### 5.10 Driver Scoring

| ID | Requirement | Role |
|----|-------------|------|
| DSC-01 | Driver score (0–100) computed from: route adherence, trip completion reliability, schedule adherence, inspection compliance, defect reporting compliance, route deviation history, fuel consumption | System |
| DSC-02 | Score is recalculated after each completed trip | System |
| DSC-03 | Score is used for automated trip assignment and reassignment | System |
| DSC-04 | Fleet Manager views driver score on driver detail | Fleet Manager |

**Score Factors:**

| Factor | Weight | Source |
|--------|--------|--------|
| Route adherence | 1/7 (~14.3%) | Route corridor deviation history |
| Trip completion reliability | 1/7 (~14.3%) | Rejection rate, cancellations |
| Schedule adherence | 1/7 (~14.3%) | On-time start/completion vs expected times |
| Inspection compliance | 1/7 (~14.3%) | Pre/post-trip inspection completion rate and inspection report acceptance rate from maintenance side |
| Defect reporting compliance | 1/7 (~14.3%) | Defect reports submitted vs actual issues |
| Route deviation history | 1/7 (~14.3%) | Frequency and severity of deviations |
| Fuel consumption | 1/7 (~14.3%) | Fuel efficiency relative to benchmarks |

**Implementation note:** Compute using the fraction `1/7` in code, not a rounded percentage. If the UI requires whole-number display, distribute the rounding remainder onto one factor (six at 14%, one at 16%) rather than rounding all seven independently.

---

### 5.11 Vehicle Health Scoring

| ID | Requirement | Role |
|----|-------------|------|
| VHS-01 | Vehicle health score (0–100) computed from five equally-weighted factors: age (fleet tenure), fuel efficiency trend, maintenance adherence, defect history, critical repair frequency | System |
| VHS-02 | Displayed on vehicle detail and vehicle list card | Fleet Manager |
| VHS-03 | Score decreases with: increasing time in fleet, declining fuel efficiency, overdue maintenance, repeated legitimate defects, frequent critical repairs | System |

**Score Factors:**

| Factor | Weight | Computed as |
|--------|--------|-------------|
| Age (fleet tenure) | 20% | `100 − (years since added to system × 10)`, floored at 0. Based on the date the vehicle was added to the system — not manufacture year. VEH-01's `year` field is retained on the record for reference but does not feed this score |
| Fuel efficiency | 20% | Vehicle's current rolling km/liter compared against its own baseline, established from its first several fuel entries (FEL-01). Declining efficiency lowers the score; defaults to 100 until enough entries exist to establish a baseline |
| Maintenance adherence | 20% | 100 if not currently overdue; deducts proportionally to how overdue the vehicle is (days or km past the MNT-02 threshold) |
| Defect history | 20% | 100 minus a fixed penalty per legitimate defect report (MNT-11) in the trailing 12 months |
| Critical repair frequency | 20% | 100 minus a fixed penalty per critical-flagged work order (WO-04) in the trailing 12 months |

**Implementation note:** This fuel-efficiency factor and Driver Score's fuel-consumption factor (Section 5.10) use the same underlying fuel entry data (FEL-01) but measure different things: Vehicle Health tracks whether a specific vehicle's efficiency is degrading over time regardless of driver; Driver Score tracks whether a specific driver's efficiency is poor regardless of vehicle. Keep these conceptually distinct during implementation — they are not duplicates.

---

### 5.12 Fleet Utilization

| ID | Requirement | Role |
|----|-------------|------|
| FUT-01 | Fleet utilization measures how efficiently vehicles and drivers are used | System |
| FUT-02 | Vehicle utilization: trip frequency, distance covered, idle time per vehicle | System |
| FUT-03 | Driver utilization: trip distribution across drivers to detect under/over-utilization | System |
| FUT-04 | Displayed on Fleet Manager dashboard | System |

---

### 5.13 Dashboard

| ID | Requirement | Role |
|----|-------------|------|
| DSH-01 | **Fleet Manager dashboard** shows live operational data: active trips, vehicles, drivers, maintenance status, notifications count, fleet utilization summary | Fleet Manager |
| DSH-02 | Fleet Manager can navigate to detailed views from dashboard cards | Fleet Manager |
| DSH-03 | **Driver dashboard** shows: assigned trips (pending, active), vehicle info, notifications | Driver |
| DSH-04 | **Maintenance Personnel dashboard** shows: assigned work orders, notifications | Maintenance Personnel |

#### 5.13.1 Analytics Insight Cards

| ID | Requirement | Role |
|----|-------------|------|
| DSH-05 | FM dashboard shows an Insight Card carousel below the operational summary (DSH-01) — 2 cards visible at a time, horizontally swipeable. This carousel view is always fixed to the current calendar month (no filter control here — see DSH-07 for where filtering lives) | System |
| DSH-06 | Six analytics categories: Fuel Expenditure, Trip Punctuality, Maintenance Labour Hours, Maintenance Expenditure, Inspection Legitimacy, Inventory Usage | System |
| DSH-07 | "View All" screen shows a period filter with four presets: `1 month`, `3 months`, `6 months`, `1 year`, applied to all 6 category cards. Default: `1 month` | Fleet Manager |
| DSH-08 | Tapping a category card, from either the carousel (DSH-05) or the View All screen (DSH-07), opens that category's detail view | Fleet Manager |
| DSH-09 | Category detail view opens with whatever period was selected on View All, and the period can be changed independently from within the detail view without navigating back | Fleet Manager |
| DSH-10 | Detail view shows a short textual summary plus ranked list(s) of the top 10 entities for the selected period | System |
| DSH-11 | **Fuel Expenditure**: two ranked lists of 10 — highest fuel-consuming trips, lowest fuel-consuming trips (from trip-linked fuel entries, see FEL-06) | System |
| DSH-12 | **Trip Punctuality**: two ranked lists of 10 — most on-time trips, most-delayed trips (actual vs expected start/end time) | System |
| DSH-13 | **Maintenance Labour Hours**: single ranked list of 10 — longest-duration work orders, with assigned Maintenance Personnel details and hours (see WO-10) | System |
| DSH-14 | **Maintenance Expenditure**: single ranked list of 10 — most expensive work orders by total cost (labour + parts, WO-07) | System |
| DSH-15 | **Inspection Legitimacy**: two ranked lists of 10 — drivers with the highest legitimate-report rate, drivers with the highest false-report rate (see MNT-11) | System |
| DSH-16 | **Inventory Usage**: aggregate total quantity consumed for the selected period, plus a single ranked list of 10 most-consumed parts | System |

---

### 5.14 Reporting & Exports

| ID | Requirement | Role |
|----|-------------|------|
| RPT-01 | Predefined reports only — no custom report builder | Fleet Manager |
| RPT-02 | **Trip Report**: trip count, distance, duration, driver, vehicle by date range | Fleet Manager |
| RPT-03 | **Maintenance Report**: work orders, costs, parts used, by vehicle/date | Fleet Manager |
| RPT-04 | **Fleet Utilization Report**: vehicle usage, driver workload distribution | Fleet Manager |
| RPT-05 | **Driver Performance Report**: driver scores, trip stats, adherence metrics | Fleet Manager |
| RPT-06 | **Vehicle Health Report**: health scores, maintenance history, defect history | Fleet Manager |
| RPT-07 | Export formats: PDF, CSV, Excel | Fleet Manager |
| RPT-08 | Reports are generated on-demand — no scheduled email delivery | Fleet Manager |

---

### 5.15 Notifications

| ID | Requirement | Role |
|----|-------------|------|
| NOT-01 | Route deviation detected (driver + fleet manager) | System |
| NOT-02 | Trip assignment (driver) | System |
| NOT-03 | Trip rejected with reason (fleet manager) | System |
| NOT-04 | Maintenance due (fleet manager) | System |
| NOT-05 | Work order assigned (maintenance personnel) | System |
| NOT-06 | Defect reported (fleet manager) | System |
| NOT-07 | Defect approved/rejected (driver) | System |
| NOT-08 | Compliance document expiring/expired (fleet manager) | System |
| NOT-09 | Low inventory threshold reached (fleet manager) | System |
| NOT-10 | Notifications are user-clearable | All |
| NOT-11 | Notifications persist until explicitly cleared by the user | System |

---

### 5.16 Draft Recovery

| ID | Requirement | Role |
|----|-------------|------|
| DFR-01 | Unsaved form data is temporarily stored locally when connectivity is interrupted | System |
| DFR-02 | Restored when the user returns to the form | System |
| DFR-03 | Supported for: defect reports, voice notes, trip remarks (driver) | Driver |
| DFR-04 | Supported for: work order remarks, labour cost entries, parts-used entries (maintenance) | Maintenance Personnel |
| DFR-05 | Supported for: vehicle forms, trip creation forms, PO forms (fleet manager) | Fleet Manager |
| DFR-06 | NOT a full offline mode — no offline trip execution, inventory management, or work order completion | System |

---

## 6. Non-Functional Requirements

### 6.1 Performance

| ID | Requirement |
|----|-------------|
| NFR-P-01 | App launches and becomes interactive within 2 seconds on iPhone 15+ |
| NFR-P-02 | Screen transitions are fluid — 60 fps with no dropped frames |
| NFR-P-03 | Supabase queries return results within 500ms (p95) for typical list/detail views |
| NFR-P-04 | Telemetry batch upload does not block UI — background async operation |
| NFR-P-05 | Dashboard loads within 1 second (aggregated view queries) |
| NFR-P-06 | Reports generate within 3 seconds for up to 12 months of data |
| NFR-P-07 | No memory leaks — verify via Instruments Allocations & Leak checks |
| NFR-P-08 | No SwiftUI constraint warnings or errors in console output |
| NFR-P-09 | No compiler warnings in build |

### 6.2 Security

| ID | Requirement |
|----|-------------|
| NFR-S-01 | All network traffic over HTTPS/TLS |
| NFR-S-02 | Authentication via Supabase Auth — email + password + OTP on every login |
| NFR-S-03 | Authorization via PostgreSQL Row Level Security (RLS) — per-row, per-role |
| NFR-S-04 | Fleet Manager has full CRUD access to all tenant data |
| NFR-S-05 | Driver and Maintenance Personnel access strictly scoped to own data (via RLS policies) |
| NFR-S-06 | API keys stored in `Info.plist`, excluded from version control via `Secrets.xcconfig` |
| NFR-S-07 | Multi-tenant data isolation enforced at database level through tenant ID column + RLS |
| NFR-S-08 | Password reset via email OTP — no plain-text password storage |
| NFR-S-09 | DPDP Act 2023 (India) compliance: user data deletable on request, data retention policies enforced |

### 6.3 Usability

| ID | Requirement |
|----|-------------|
| NFR-U-01 | Follow Apple HIG (Human Interface Guidelines) for iOS 18 |
| NFR-U-02 | Native split-view and navigation for iPad (not scaled iPhone layout) |
| NFR-U-03 | Dark mode and light mode support |
| NFR-U-04 | Dynamic Type support for accessibility |
| NFR-U-05 | VoiceOver support for core screens |
| NFR-U-06 | Error states, empty states, and loading states for all list/detail screens |
| NFR-U-07 | Pull-to-refresh on all list screens |
| NFR-U-08 | All user-facing text in English |

### 6.4 Scalability

| ID | Requirement |
|----|-------------|
| NFR-SC-01 | Support tens-to-hundreds of vehicles per tenant |
| NFR-SC-02 | Support multiple concurrent trips per tenant |
| NFR-SC-03 | Support tens of tenants without performance degradation |
| NFR-SC-04 | Telemetry data partitioned by month (PostgreSQL partitioning) — auto-purge partitions older than 12 months |
| NFR-SC-05 | Materialized views for dashboard + reports (refreshed on schedule) |
| NFR-SC-06 | Architecture supports future localization without structural changes |

### 6.5 Reliability & Availability

| ID | Requirement |
|----|-------------|
| NFR-R-01 | Supabase handles uptime — app handles degraded states gracefully |
| NFR-R-02 | GPS data buffer prevents data loss during temporary connectivity loss |
| NFR-R-03 | Draft recovery prevents loss of unsaved form data |
| NFR-R-04 | All async operations have proper error handling with user-facing error messages |
| NFR-R-05 | Data consistency via Supabase transactions + RLS enforcement |

---

## 7. Data Retention Policy

| Data Type | Retention Period |
|-----------|-----------------|
| GPS Telemetry | 12 months (partitioned, auto-purged) |
| Trip History (receipts, expense entries) | 5 years |
| Maintenance History | Permanent |
| Inventory History | 5 years |
| Inspection History (pre/post trip) | 5 years |
| Fuel Entry History | 5 years |
| Toll/Receipt Images | 5 years |
| Notification History | User-clearable (no forced retention) |
| User Accounts | Until archived (soft-delete) |
| Vehicle Records | Until archived (soft-delete) |

---

## 8. Glossary

| Term | Definition |
|------|------------|
| **Fleet Manager** | User role — manages system, users, vehicles, trips, maintenance, reports, updates inventory |
| **Driver** | User role — operates vehicles, completes trips, reports defects |
| **Maintenance Personnel** | User role — performs repairs, completes work orders, uses inventory |
| **Route Corridor** | Overlapping circular geofence regions along the route polyline |
| **Work Order** | A maintenance task with full lifecycle tracking |
| **Driver Score** | 0–100 rule-based score for driver assignment decisions |
| **Vehicle Health Score** | 0–100 rule-based score indicating vehicle condition |
| **Draft Recovery** | Temporary local storage of unsaved form data during connectivity loss |
| **Pre-Trip Inspection** | Checklist-based vehicle inspection performed by driver before starting a trip |
| **Post-Trip Inspection** | Checklist-based vehicle inspection performed by driver after completing a trip |
| **Trip Report** | Compiled record of a completed trip: summary, inspection, expenses, route deviations |
| **OCR Receipt** | Toll/expense receipt processed by Apple Vision framework for automatic data extraction |
| **Tenant** | A single company/organization using the FMS (multi-tenant isolation) |
| **Vehicle Type (enum)** | Fixed set of vehicle categories: `van`, `car`, `truck`, `bus` — used for driver authorization and trip assignment filtering |
| **DL Class** | Driving license class: `LMV` (Light Motor Vehicle) or `HMV` (Heavy Motor Vehicle); a driver may hold one or both. Determines which vehicle types the driver is authorized to operate |
| **Assignment Algorithm** | The rule-based process for selecting a driver for a trip: hard-filter by authorized vehicle type match, then rank candidates by proximity to start point, availability, schedule fit, and driver score |
| **Masked Aadhaar** | Aadhaar number displayed with only the last 4 digits visible (e.g., `XXXX-XXXX-1234`); the full 12-digit number is never stored or logged |
