# F1 Data Cache Structure Documentation

## Overview

This document provides a comprehensive overview of the Formula 1 data cache structure used in this project. The cache contains telemetry and race data from the 2021-2025 F1 seasons, organized in a hierarchical directory structure by year, race event, and session type.

## Cache Statistics

- **Total Files**: 1,510
- **F1 Data Files (.ff1pkl)**: 1,397
- **System Files (.DS_Store)**: 112
- **FastF1 HTTP Cache**: 1 SQLite database file
- **Years Covered**: 2021, 2022, 2023, 2024, 2025
- **Total Race Events**: 118
- **Total Sessions**: 139 (118 Race + 21 Sprint)
- **Sprint Race Events**: 21

## Directory Structure Pattern

The cache follows a consistent hierarchical structure:

```
cache/
├── YEAR/
│   ├── YEAR-MM-DD_Race_Name/
│   │   ├── YEAR-MM-DD_Race/
│   │   │   ├── car_data.ff1pkl
│   │   │   ├── weather_data.ff1pkl
│   │   │   ├── driver_info.ff1pkl
│   │   │   ├── position_data.ff1pkl
│   │   │   ├── lap_count.ff1pkl
│   │   │   ├── session_status_data.ff1pkl
│   │   │   ├── race_control_messages.ff1pkl
│   │   │   ├── timing_app_data.ff1pkl
│   │   │   ├── track_status_data.ff1pkl
│   │   │   ├── session_info.ff1pkl
│   │   │   └── _extended_timing_data.ff1pkl
│   │   └── YEAR-MM-DD_Sprint/ (if applicable)
│   │       └── [same files as Race]
│   └── .DS_Store (system file)
└── fastf1_http_cache.sqlite
```

## File Types in Each Session Directory

Each race and sprint session directory contains exactly 11 data files:

| File Name | Description |
|-----------|-------------|
| `car_data.ff1pkl` | Telemetry data from all cars including speed, throttle, brake, etc. |
| `weather_data.ff1pkl` | Weather conditions during the session |
| `driver_info.ff1pkl` | Driver identification and team information |
| `position_data.ff1pkl` | GPS coordinates and track position data |
| `lap_count.ff1pkl` | Lap counting and timing information |
| `session_status_data.ff1pkl` | Session state (green flag, yellow flag, red flag, etc.) |
| `race_control_messages.ff1pkl` | Official messages from race control |
| `timing_app_data.ff1pkl` | Detailed timing sector and lap data |
| `track_status_data.ff1pkl` | Track condition and safety car information |
| `session_info.ff1pkl` | General session metadata and configuration |
| `_extended_timing_data.ff1pkl` | Extended timing analysis and statistics |

## Complete Directory Tree

### 2021 Season (22 Race Events, 3 with Sprint)

```
cache/2021/
├── 2021-03-28_Bahrain_Grand_Prix/
│   └── 2021-03-28_Race/
├── 2021-04-18_Emilia_Romagna_Grand_Prix/
│   └── 2021-04-18_Race/
├── 2021-05-02_Portuguese_Grand_Prix/
│   └── 2021-05-02_Race/
├── 2021-05-09_Spanish_Grand_Prix/
│   └── 2021-05-09_Race/
├── 2021-05-23_Monaco_Grand_Prix/
│   └── 2021-05-23_Race/
├── 2021-06-06_Azerbaijan_Grand_Prix/
│   └── 2021-06-06_Race/
├── 2021-06-20_French_Grand_Prix/
│   └── 2021-06-20_Race/
├── 2021-06-27_Styrian_Grand_Prix/
│   └── 2021-06-27_Race/
├── 2021-07-04_Austrian_Grand_Prix/
│   └── 2021-07-04_Race/
├── 2021-07-18_British_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2021-07-17_Sprint/
│   └── 2021-07-18_Race/
├── 2021-08-01_Hungarian_Grand_Prix/
│   └── 2021-08-01_Race/
├── 2021-08-29_Belgian_Grand_Prix/
│   └── 2021-08-29_Race/
├── 2021-09-05_Dutch_Grand_Prix/
│   └── 2021-09-05_Race/
├── 2021-09-12_Italian_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2021-09-11_Sprint/
│   └── 2021-09-12_Race/
├── 2021-09-26_Russian_Grand_Prix/
│   └── 2021-09-26_Race/
├── 2021-10-10_Turkish_Grand_Prix/
│   └── 2021-10-10_Race/
├── 2021-10-24_United_States_Grand_Prix/
│   └── 2021-10-24_Race/
├── 2021-11-07_Mexico_City_Grand_Prix/
│   └── 2021-11-07_Race/
├── 2021-11-14_São_Paulo_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2021-11-13_Sprint/
│   └── 2021-11-14_Race/
├── 2021-11-21_Qatar_Grand_Prix/
│   └── 2021-11-21_Race/
├── 2021-12-05_Saudi_Arabian_Grand_Prix/
│   └── 2021-12-05_Race/
└── 2021-12-12_Abu_Dhabi_Grand_Prix/
    └── 2021-12-12_Race/
```

### 2022 Season (22 Race Events, 3 with Sprint)

```
cache/2022/
├── 2022-03-20_Bahrain_Grand_Prix/
│   └── 2022-03-20_Race/
├── 2022-03-27_Saudi_Arabian_Grand_Prix/
│   └── 2022-03-27_Race/
├── 2022-04-10_Australian_Grand_Prix/
│   └── 2022-04-10_Race/
├── 2022-04-24_Emilia_Romagna_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2022-04-23_Sprint/
│   └── 2022-04-24_Race/
├── 2022-05-08_Miami_Grand_Prix/
│   └── 2022-05-08_Race/
├── 2022-05-22_Spanish_Grand_Prix/
│   └── 2022-05-22_Race/
├── 2022-05-29_Monaco_Grand_Prix/
│   └── 2022-05-29_Race/
├── 2022-06-12_Azerbaijan_Grand_Prix/
│   └── 2022-06-12_Race/
├── 2022-06-19_Canadian_Grand_Prix/
│   └── 2022-06-19_Race/
├── 2022-07-03_British_Grand_Prix/
│   └── 2022-07-03_Race/
├── 2022-07-10_Austrian_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2022-07-09_Sprint/
│   └── 2022-07-10_Race/
├── 2022-07-24_French_Grand_Prix/
│   └── 2022-07-24_Race/
├── 2022-07-31_Hungarian_Grand_Prix/
│   └── 2022-07-31_Race/
├── 2022-08-28_Belgian_Grand_Prix/
│   └── 2022-08-28_Race/
├── 2022-09-04_Dutch_Grand_Prix/
│   └── 2022-09-04_Race/
├── 2022-09-11_Italian_Grand_Prix/
│   └── 2022-09-11_Race/
├── 2022-10-02_Singapore_Grand_Prix/
│   └── 2022-10-02_Race/
├── 2022-10-09_Japanese_Grand_Prix/
│   └── 2022-10-09_Race/
├── 2022-10-23_United_States_Grand_Prix/
│   └── 2022-10-23_Race/
├── 2022-10-30_Mexico_City_Grand_Prix/
│   └── 2022-10-30_Race/
├── 2022-11-13_São_Paulo_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2022-11-12_Sprint/
│   └── 2022-11-13_Race/
└── 2022-11-20_Abu_Dhabi_Grand_Prix/
    └── 2022-11-20_Race/
```

### 2023 Season (22 Race Events, 6 with Sprint)

```
cache/2023/
├── 2023-03-05_Bahrain_Grand_Prix/
│   └── 2023-03-05_Race/
├── 2023-03-19_Saudi_Arabian_Grand_Prix/
│   └── 2023-03-19_Race/
├── 2023-04-02_Australian_Grand_Prix/
│   └── 2023-04-02_Race/
├── 2023-04-30_Azerbaijan_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2023-04-29_Sprint/
│   └── 2023-04-30_Race/
├── 2023-05-07_Miami_Grand_Prix/
│   └── 2023-05-07_Race/
├── 2023-05-28_Monaco_Grand_Prix/
│   └── 2023-05-28_Race/
├── 2023-06-04_Spanish_Grand_Prix/
│   └── 2023-06-04_Race/
├── 2023-06-18_Canadian_Grand_Prix/
│   └── 2023-06-18_Race/
├── 2023-07-02_Austrian_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2023-07-01_Sprint/
│   └── 2023-07-02_Race/
├── 2023-07-09_British_Grand_Prix/
│   └── 2023-07-09_Race/
├── 2023-07-23_Hungarian_Grand_Prix/
│   └── 2023-07-23_Race/
├── 2023-07-30_Belgian_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2023-07-29_Sprint/
│   └── 2023-07-30_Race/
├── 2023-08-27_Dutch_Grand_Prix/
│   └── 2023-08-27_Race/
├── 2023-09-03_Italian_Grand_Prix/
│   └── 2023-09-03_Race/
├── 2023-09-17_Singapore_Grand_Prix/
│   └── 2023-09-17_Race/
├── 2023-09-24_Japanese_Grand_Prix/
│   └── 2023-09-24_Race/
├── 2023-10-08_Qatar_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2023-10-07_Sprint/
│   └── 2023-10-08_Race/
├── 2023-10-22_United_States_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2023-10-21_Sprint/
│   └── 2023-10-22_Race/
├── 2023-10-29_Mexico_City_Grand_Prix/
│   └── 2023-10-29_Race/
├── 2023-11-05_São_Paulo_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2023-11-04_Sprint/
│   └── 2023-11-05_Race/
├── 2023-11-18_Las_Vegas_Grand_Prix/
│   └── 2023-11-18_Race/
└── 2023-11-26_Abu_Dhabi_Grand_Prix/
    └── 2023-11-26_Race/
```

### 2024 Season (24 Race Events, 6 with Sprint)

```
cache/2024/
├── 2024-03-02_Bahrain_Grand_Prix/
│   └── 2024-03-02_Race/
├── 2024-03-09_Saudi_Arabian_Grand_Prix/
│   └── 2024-03-09_Race/
├── 2024-03-24_Australian_Grand_Prix/
│   └── 2024-03-24_Race/
├── 2024-04-07_Japanese_Grand_Prix/
│   └── 2024-04-07_Race/
├── 2024-04-21_Chinese_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2024-04-20_Sprint/
│   └── 2024-04-21_Race/
├── 2024-05-05_Miami_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2024-05-04_Sprint/
│   └── 2024-05-05_Race/
├── 2024-05-19_Emilia_Romagna_Grand_Prix/
│   └── 2024-05-19_Race/
├── 2024-05-26_Monaco_Grand_Prix/
│   └── 2024-05-26_Race/
├── 2024-06-09_Canadian_Grand_Prix/
│   └── 2024-06-09_Race/
├── 2024-06-23_Spanish_Grand_Prix/
│   └── 2024-06-23_Race/
├── 2024-06-30_Austrian_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2024-06-29_Sprint/
│   └── 2024-06-30_Race/
├── 2024-07-07_British_Grand_Prix/
│   └── 2024-07-07_Race/
├── 2024-07-21_Hungarian_Grand_Prix/
│   └── 2024-07-21_Race/
├── 2024-07-28_Belgian_Grand_Prix/
│   └── 2024-07-28_Race/
├── 2024-08-25_Dutch_Grand_Prix/
│   └── 2024-08-25_Race/
├── 2024-09-01_Italian_Grand_Prix/
│   └── 2024-09-01_Race/
├── 2024-09-15_Azerbaijan_Grand_Prix/
│   └── 2024-09-15_Race/
├── 2024-09-22_Singapore_Grand_Prix/
│   └── 2024-09-22_Race/
├── 2024-10-20_United_States_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2024-10-19_Sprint/
│   └── 2024-10-20_Race/
├── 2024-10-27_Mexico_City_Grand_Prix/
│   └── 2024-10-27_Race/
├── 2024-11-03_São_Paulo_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2024-11-02_Sprint/
│   └── 2024-11-03_Race/
├── 2024-11-23_Las_Vegas_Grand_Prix/
│   └── 2024-11-23_Race/
├── 2024-12-01_Qatar_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2024-11-30_Sprint/
│   └── 2024-12-01_Race/
└── 2024-12-08_Abu_Dhabi_Grand_Prix/
    └── 2024-12-08_Race/
```

### 2025 Season (16 Race Events, 3 with Sprint) - Partial Season

```
cache/2025/
├── 2025-03-16_Australian_Grand_Prix/
│   └── 2025-03-16_Race/
├── 2025-03-23_Chinese_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2025-03-22_Sprint/
│   └── 2025-03-23_Race/
├── 2025-04-06_Japanese_Grand_Prix/
│   └── 2025-04-06_Race/
├── 2025-04-13_Bahrain_Grand_Prix/
│   └── 2025-04-13_Race/
├── 2025-04-20_Saudi_Arabian_Grand_Prix/
│   └── 2025-04-20_Race/
├── 2025-05-04_Miami_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2025-05-03_Sprint/
│   └── 2025-05-04_Race/
├── 2025-05-18_Emilia_Romagna_Grand_Prix/
│   └── 2025-05-18_Race/
├── 2025-05-25_Monaco_Grand_Prix/
│   └── 2025-05-25_Race/
├── 2025-06-01_Spanish_Grand_Prix/
│   └── 2025-06-01_Race/
├── 2025-06-15_Canadian_Grand_Prix/
│   └── 2025-06-15_Race/
├── 2025-06-29_Austrian_Grand_Prix/
│   └── 2025-06-29_Race/
├── 2025-07-06_British_Grand_Prix/
│   └── 2025-07-06_Race/
├── 2025-07-27_Belgian_Grand_Prix/ ⭐ Sprint Weekend
│   ├── 2025-07-26_Sprint/
│   └── 2025-07-27_Race/
├── 2025-08-03_Hungarian_Grand_Prix/
│   └── 2025-08-03_Race/
├── 2025-08-31_Dutch_Grand_Prix/
│   └── 2025-08-31_Race/
└── 2025-09-07_Italian_Grand_Prix/
    └── 2025-09-07_Race/
```

## Sprint Race Weekends by Year

### Sprint Weekend Evolution

- **2021**: 3 Sprint weekends (British, Italian, São Paulo)
- **2022**: 3 Sprint weekends (Emilia Romagna, Austrian, São Paulo)
- **2023**: 6 Sprint weekends (Azerbaijan, Austrian, Belgian, Qatar, US, São Paulo)
- **2024**: 6 Sprint weekends (Chinese, Miami, Austrian, US, São Paulo, Qatar)
- **2025**: 3 Sprint weekends so far (Chinese, Miami, Belgian)

## Technical Notes

### Data Format
- All F1 telemetry data is stored in FastF1's proprietary `.ff1pkl` format
- These are Python pickle files optimized for F1 data structures
- Each file contains pandas DataFrames and custom FastF1 objects

### System Files
- `.DS_Store` files are macOS system files (112 total)
- `fastf1_http_cache.sqlite` is FastF1's HTTP request cache database
- These files can be safely ignored for data analysis purposes

### Cache Performance
- The cache structure allows for efficient data retrieval by year, race, and session
- Total cache size represents comprehensive F1 telemetry data from 5 seasons
- Each session contains approximately 50-100MB of telemetry data

## Usage Guidelines

1. **Navigation**: Use the year/race/session hierarchy to locate specific data
2. **Sprint Identification**: Sprint weekends are marked with ⭐ in the structure above
3. **Data Consistency**: All sessions contain the same 11 data file types
4. **File Access**: Use FastF1 library to load and process `.ff1pkl` files
5. **System Files**: Filter out `.DS_Store` files when processing directories

This cache structure provides a comprehensive foundation for F1 data analysis across multiple seasons, with consistent organization and complete telemetry coverage for both race and sprint sessions.