import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PixelopolisApp());
}

class PixelopolisApp extends StatelessWidget {
  const PixelopolisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixelopolis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CityScreen(),
    );
  }
}

// Cell types - SimCity style with zones and infrastructure
enum CellType {
  street,
  empty,

  // Zones (placed by player, develop into buildings)
  residentialZone,
  commercialZone,
  industrialZone,

  // Infrastructure
  powerPlant,
  powerLine,
  waterPump,
  waterPipe,
  powerLineAndWaterPipe, // Combined infrastructure for crossing

  // Services
  policeStation,
  fireStation,
  hospital,
  school,

  // Developed buildings (created automatically from zones)
  residentialLow,    // Houses
  residentialMedium, // Apartments
  residentialHigh,   // Condos
  commercialLow,     // Small shops
  commercialMedium,  // Offices
  commercialHigh,    // Skyscrapers
  industrialLow,     // Warehouses
  industrialMedium,  // Factories
  industrialHigh,    // Heavy industry

  // Special buildings (don't need roads)
  park,
  playground,
  fountain,
  garden,
  statue,

  // Additional services
  library,
  museum,
  stadium,
  cityHall,
}

// Game speed options
enum GameSpeed {
  paused,
  slow,
  medium,
  fast,
}

class Building {
  final CellType type;
  final int income;
  final int cost;
  final Color topColor;
  final Color sideColor;
  final String name;
  final String emoji;

  Building({
    required this.type,
    required this.income,
    required this.cost,
    required this.topColor,
    required this.sideColor,
    required this.name,
    required this.emoji,
  });
}

// Vehicle class with position on grid
class Vehicle {
  double gridRow; // Changed to double for smooth movement
  double gridCol; // Changed to double for smooth movement
  final Color color;
  final int reward;
  final String emoji;
  bool tapped = false;
  double animationOffset = 0.0;

  // Movement properties
  int direction = 0; // 0=right, 1=down, 2=left, 3=up
  double moveSpeed = 0.05; // Cells per animation frame

  Vehicle({
    required this.gridRow,
    required this.gridCol,
    required this.color,
    required this.reward,
    required this.emoji,
  });
}

// Floating text for coin animations
class FloatingText {
  final String text;
  final double startX;
  final double startY;
  double opacity = 1.0;
  double offsetY = 0.0;
  final DateTime createdAt;

  FloatingText({
    required this.text,
    required this.startX,
    required this.startY,
  }) : createdAt = DateTime.now();
}

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  // Game state
  int coins = 5000; // Start with plenty of money for infrastructure
  int population = 0;
  List<List<CellType>> cityGrid = [];
  List<Vehicle> vehicles = [];
  Timer? vehicleSpawnTimer;
  Timer? idleIncomeTimer;
  Timer? vehicleAnimationTimer;
  Timer? zoneGrowthTimer; // For auto-development of zones
  Timer? gameClockTimer; // For updating the game clock display

  // Game time tracking
  DateTime gameStartTime = DateTime.now();
  int elapsedSeconds = 0;
  int gameCycle = 0; // Like SimCity months/cycles

  // Grid size - larger grid makes roads appear thinner
  final int gridSize = 31;

  // Building selection
  CellType? selectedBuilding;
  bool bulldozerMode = false;
  bool infoMode = false;

  // Underground view toggle (like original SimCity)
  bool undergroundView = false;

  // Game speed control
  GameSpeed gameSpeed = GameSpeed.medium;

  // Challenge mode - infrastructure required for zones to develop
  bool infrastructureRequired = false;

  // Menu category expansion
  String? expandedCategory; // null, 'zones', 'utilities', 'services', 'special'

  // Zoom level for city grid (0.5x to 3.0x)
  double zoomLevel = 1.0;

  // Progression system
  int playerLevel = 1;
  int experience = 0;
  int experienceToNextLevel = 300; // Higher starting threshold

  // Floating text animations
  List<FloatingText> floatingTexts = [];
  Timer? floatingTextTimer;

  // Building upgrades (stores upgrade level 0-2 for each cell)
  List<List<int>> buildingUpgrades = [];

  // Building active state (true = on/active, false = off/inactive)
  List<List<bool>> buildingActive = [];

  // Construction progress (0.0 = just started, 1.0 = complete)
  List<List<double>> constructionProgress = [];
  Timer? constructionAnimationTimer;

  // Achievement system
  List<String> unlockedAchievements = [];
  List<String> achievementNotifications = [];
  Timer? achievementNotificationTimer;

  // SimCity systems
  // Power grid - tracks which cells have power
  List<List<bool>> powerGrid = [];
  // Water grid - tracks which cells have water
  List<List<bool>> waterGrid = [];

  // RCI Demand (-100 to +100, positive means demand)
  double residentialDemand = 50.0;
  double commercialDemand = 30.0;
  double industrialDemand = 40.0;

  // Budget system
  int monthlyIncome = 0;
  int monthlyExpenses = 0;
  double taxRate = 7.0; // 7% tax rate

  // Service coverage (stores coverage level 0-10 for each cell)
  List<List<int>> policeCoverage = [];
  List<List<int>> fireCoverage = [];
  List<List<int>> hospitalCoverage = [];
  List<List<int>> schoolCoverage = [];

  // City ratings and statistics (0-100)
  double crimeRate = 50.0; // Higher = more crime
  double educationRate = 50.0; // Higher = better education
  double healthRate = 50.0; // Higher = better health
  double fireProtectionRate = 50.0; // Higher = better fire protection

  // Ordinances (city policies that can be enacted)
  Map<String, bool> ordinances = {
    'legalize_gambling': false, // +income, +crime
    'neighborhood_watch': false, // -crime, -coins cost
    'pro_reading_campaign': false, // +education, -coins cost
    'free_clinics': false, // +health, -coins cost
    'smoke_detector_program': false, // +fire protection, -coins cost
    'energy_conservation': false, // -power maintenance cost
    'tourism_promotion': false, // +commercial demand, +income
    'recycling_program': false, // -pollution (future), -coins cost
  };

  // Ordinance costs (monthly)
  Map<String, int> ordinanceCosts = {
    'legalize_gambling': -50, // negative = income
    'neighborhood_watch': 30,
    'pro_reading_campaign': 25,
    'free_clinics': 40,
    'smoke_detector_program': 20,
    'energy_conservation': 0, // reduces other costs
    'tourism_promotion': 35,
    'recycling_program': 30,
  };

  // Unlock requirements (level needed to unlock each building)
  // All unlocked from start for SimCity-style gameplay
  final Map<CellType, int> buildingUnlockLevel = {
    CellType.residentialZone: 1,
    CellType.park: 1,
    CellType.commercialZone: 1,
    CellType.powerPlant: 1,
    CellType.waterPump: 1,
    CellType.industrialZone: 1,
    CellType.policeStation: 1,
    CellType.fireStation: 1,
    CellType.hospital: 1,
    CellType.school: 1,
    CellType.powerLine: 1,
    CellType.waterPipe: 1,
    // New parks
    CellType.playground: 1,
    CellType.fountain: 1,
    CellType.garden: 1,
    CellType.statue: 1,
    // New services
    CellType.library: 1,
    CellType.museum: 1,
    CellType.stadium: 1,
    CellType.cityHall: 1,
  };

  // Building definitions with isometric colors - SimCity style
  final Map<CellType, Building> buildings = {
    // Zones
    CellType.residentialZone: Building(
      type: CellType.residentialZone,
      name: 'Residential',
      emoji: '🟩',
      cost: 10,
      income: 0,
      topColor: Color(0xFF4CAF50),
      sideColor: Color(0xFF2E7D32),
    ),
    CellType.commercialZone: Building(
      type: CellType.commercialZone,
      name: 'Commercial',
      emoji: '🟦',
      cost: 10,
      income: 0,
      topColor: Color(0xFF2196F3),
      sideColor: Color(0xFF0D47A1),
    ),
    CellType.industrialZone: Building(
      type: CellType.industrialZone,
      name: 'Industrial',
      emoji: '🟨',
      cost: 10,
      income: 0,
      topColor: Color(0xFFFFEB3B),
      sideColor: Color(0xFFF57F17),
    ),

    // Infrastructure
    CellType.powerPlant: Building(
      type: CellType.powerPlant,
      name: 'Power Plant',
      emoji: '⚡',
      cost: 500,
      income: -50, // Maintenance cost
      topColor: Color(0xFF607D8B),
      sideColor: Color(0xFF263238),
    ),
    CellType.powerLine: Building(
      type: CellType.powerLine,
      name: 'Power Line',
      emoji: '⚡',
      cost: 5,
      income: -1,
      topColor: Color(0xFF9E9E9E),
      sideColor: Color(0xFF616161),
    ),
    CellType.waterPump: Building(
      type: CellType.waterPump,
      name: 'Water Pump',
      emoji: '💧',
      cost: 300,
      income: -30,
      topColor: Color(0xFF00BCD4),
      sideColor: Color(0xFF006064),
    ),
    CellType.waterPipe: Building(
      type: CellType.waterPipe,
      name: 'Water Pipe',
      emoji: '💧',
      cost: 5,
      income: -1,
      topColor: Color(0xFF4DD0E1),
      sideColor: Color(0xFF00838F),
    ),
    CellType.powerLineAndWaterPipe: Building(
      type: CellType.powerLineAndWaterPipe,
      name: 'Power+Water',
      emoji: '⚡💧',
      cost: 0, // No cost, created by crossing
      income: -2, // Combined maintenance
      topColor: Color(0xFF9E9E9E),
      sideColor: Color(0xFF616161),
    ),

    // Services
    CellType.policeStation: Building(
      type: CellType.policeStation,
      name: 'Police',
      emoji: '🚓',
      cost: 400,
      income: -40,
      topColor: Color(0xFF1976D2),
      sideColor: Color(0xFF0D47A1),
    ),
    CellType.fireStation: Building(
      type: CellType.fireStation,
      name: 'Fire Station',
      emoji: '🚒',
      cost: 400,
      income: -40,
      topColor: Color(0xFFF44336),
      sideColor: Color(0xFFB71C1C),
    ),
    CellType.hospital: Building(
      type: CellType.hospital,
      name: 'Hospital',
      emoji: '🏥',
      cost: 500,
      income: -50,
      topColor: Color(0xFFE91E63),
      sideColor: Color(0xFFC2185B),
    ),
    CellType.school: Building(
      type: CellType.school,
      name: 'School',
      emoji: '🏫',
      cost: 300,
      income: -30,
      topColor: Color(0xFF9C27B0),
      sideColor: Color(0xFF7B1FA2),
    ),

    // Developed buildings
    CellType.residentialLow: Building(
      type: CellType.residentialLow,
      name: 'House',
      emoji: '🏠',
      cost: 0,
      income: 5,
      topColor: Color(0xFF4CAF50),
      sideColor: Color(0xFF2E7D32),
    ),
    CellType.residentialMedium: Building(
      type: CellType.residentialMedium,
      name: 'Apartments',
      emoji: '🏘️',
      cost: 0,
      income: 15,
      topColor: Color(0xFF66BB6A),
      sideColor: Color(0xFF388E3C),
    ),
    CellType.residentialHigh: Building(
      type: CellType.residentialHigh,
      name: 'Condos',
      emoji: '🏙️',
      cost: 0,
      income: 30,
      topColor: Color(0xFF81C784),
      sideColor: Color(0xFF43A047),
    ),
    CellType.commercialLow: Building(
      type: CellType.commercialLow,
      name: 'Shop',
      emoji: '🏪',
      cost: 0,
      income: 10,
      topColor: Color(0xFF2196F3),
      sideColor: Color(0xFF0D47A1),
    ),
    CellType.commercialMedium: Building(
      type: CellType.commercialMedium,
      name: 'Office',
      emoji: '🏢',
      cost: 0,
      income: 25,
      topColor: Color(0xFF42A5F5),
      sideColor: Color(0xFF1565C0),
    ),
    CellType.commercialHigh: Building(
      type: CellType.commercialHigh,
      name: 'Skyscraper',
      emoji: '🏙️',
      cost: 0,
      income: 50,
      topColor: Color(0xFF64B5F6),
      sideColor: Color(0xFF1976D2),
    ),
    CellType.industrialLow: Building(
      type: CellType.industrialLow,
      name: 'Warehouse',
      emoji: '🏭',
      cost: 0,
      income: 8,
      topColor: Color(0xFFFFEB3B),
      sideColor: Color(0xFFF57F17),
    ),
    CellType.industrialMedium: Building(
      type: CellType.industrialMedium,
      name: 'Factory',
      emoji: '🏭',
      cost: 0,
      income: 20,
      topColor: Color(0xFFFDD835),
      sideColor: Color(0xFFF9A825),
    ),
    CellType.industrialHigh: Building(
      type: CellType.industrialHigh,
      name: 'Heavy Industry',
      emoji: '🏭',
      cost: 0,
      income: 40,
      topColor: Color(0xFFFFEE58),
      sideColor: Color(0xFFFBC02D),
    ),

    // Special
    CellType.park: Building(
      type: CellType.park,
      name: 'Park',
      emoji: '🌳',
      cost: 50,
      income: 0,
      topColor: Color(0xFF8BC34A),
      sideColor: Color(0xFF33691E),
    ),
    CellType.playground: Building(
      type: CellType.playground,
      name: 'Playground',
      emoji: '🎠',
      cost: 30,
      income: 0,
      topColor: Color(0xFFFFEB3B),
      sideColor: Color(0xFFF57F17),
    ),
    CellType.fountain: Building(
      type: CellType.fountain,
      name: 'Fountain',
      emoji: '⛲',
      cost: 40,
      income: 0,
      topColor: Color(0xFF00BCD4),
      sideColor: Color(0xFF006064),
    ),
    CellType.garden: Building(
      type: CellType.garden,
      name: 'Garden',
      emoji: '🌺',
      cost: 35,
      income: 0,
      topColor: Color(0xFFE91E63),
      sideColor: Color(0xFFC2185B),
    ),
    CellType.statue: Building(
      type: CellType.statue,
      name: 'Statue',
      emoji: '🗿',
      cost: 60,
      income: 0,
      topColor: Color(0xFF9E9E9E),
      sideColor: Color(0xFF616161),
    ),

    // Additional Services
    CellType.library: Building(
      type: CellType.library,
      name: 'Library',
      emoji: '📚',
      cost: 250,
      income: -25,
      topColor: Color(0xFF795548),
      sideColor: Color(0xFF4E342E),
    ),
    CellType.museum: Building(
      type: CellType.museum,
      name: 'Museum',
      emoji: '🏛️',
      cost: 350,
      income: -35,
      topColor: Color(0xFF607D8B),
      sideColor: Color(0xFF263238),
    ),
    CellType.stadium: Building(
      type: CellType.stadium,
      name: 'Stadium',
      emoji: '🏟️',
      cost: 800,
      income: -80,
      topColor: Color(0xFF3F51B5),
      sideColor: Color(0xFF1A237E),
    ),
    CellType.cityHall: Building(
      type: CellType.cityHall,
      name: 'City Hall',
      emoji: '🏛️',
      cost: 500,
      income: -50,
      topColor: Color(0xFFFFEB3B),
      sideColor: Color(0xFFF57F17),
    ),
  };

  @override
  void initState() {
    super.initState();

    // Initialize all grids
    if (buildingUpgrades.isEmpty) {
      buildingUpgrades = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => 0);
      });
    }
    if (buildingActive.isEmpty) {
      buildingActive = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => true); // All buildings start active
      });
    }
    if (constructionProgress.isEmpty) {
      constructionProgress = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => 1.0); // Start fully constructed
      });
    }
    if (powerGrid.isEmpty) {
      powerGrid = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => false);
      });
    }
    if (waterGrid.isEmpty) {
      waterGrid = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => false);
      });
    }
    if (policeCoverage.isEmpty) {
      policeCoverage = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => 0);
      });
    }
    if (fireCoverage.isEmpty) {
      fireCoverage = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => 0);
      });
    }
    if (hospitalCoverage.isEmpty) {
      hospitalCoverage = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => 0);
      });
    }
    if (schoolCoverage.isEmpty) {
      schoolCoverage = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => 0);
      });
    }

    // Try to load saved game, otherwise initialize new city
    loadGame().then((_) {
      // If no saved game, initialize fresh city
      if (cityGrid.isEmpty || cityGrid.every((row) => row.every((cell) => cell == CellType.empty))) {
        initializeCity();
      }

      // Ensure constructionProgress is initialized after loading (for old saves)
      if (constructionProgress.isEmpty) {
        setState(() {
          constructionProgress = List.generate(gridSize, (row) {
            return List.generate(gridSize, (col) => 1.0); // All existing buildings fully constructed
          });
        });
      }

      // Update power and water grids after loading
      updatePowerGrid();
      updateWaterGrid();
      updateServiceCoverage();
    });

    // Start vehicle spawning
    vehicleSpawnTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      spawnVehicle();
    });

    // Start idle income generation
    idleIncomeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      generateIdleIncome();
    });

    // Start vehicle animation
    vehicleAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      animateVehicles();
    });

    // Start floating text animation
    floatingTextTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      animateFloatingTexts();
    });

    // Zone growth timer - zones develop into buildings AND buildings auto-upgrade
    zoneGrowthTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      processZoneGrowth();
      processBuildingEvolution();
      updateCityStatistics(); // Update crime, education, health stats
    });

    // Auto-save every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (_) {
      saveGame();
    });

    // Game clock timer - updates every second
    gameClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (gameSpeed != GameSpeed.paused) {
        setState(() {
          elapsedSeconds++;
          // Increment cycle every 10 seconds (like SimCity months)
          if (elapsedSeconds % 10 == 0) {
            gameCycle++;
            // Random events happen every cycle
            triggerRandomEvent();
          }
        });
      }
    });

    // Construction animation timer - animates buildings growing
    constructionAnimationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (gameSpeed != GameSpeed.paused) {
        setState(() {
          for (int row = 0; row < gridSize; row++) {
            for (int col = 0; col < gridSize; col++) {
              if (constructionProgress[row][col] < 1.0) {
                // Buildings take 2 seconds to construct (40 ticks at 50ms)
                constructionProgress[row][col] += 0.025;
                if (constructionProgress[row][col] > 1.0) {
                  constructionProgress[row][col] = 1.0;
                }
              }
            }
          }
        });
      }
    });

    // Achievement notification timer - clears notifications after 3 seconds
    achievementNotificationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        achievementNotifications.removeWhere((notif) => false); // Will manage this better
      });
    });
  }

  void initializeCity() {
    // Create grid with streets in a pattern
    cityGrid = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) {
        // Every 5th row and column is a street (thinner roads)
        if (row % 5 == 0 || col % 5 == 0) {
          return CellType.street;
        }
        return CellType.empty;
      });
    });

    // Place power plants at strategic locations
    cityGrid[9][9] = CellType.powerPlant;
    cityGrid[21][9] = CellType.powerPlant;
    cityGrid[9][21] = CellType.powerPlant;
    cityGrid[21][21] = CellType.powerPlant;

    // Place water pumps at strategic locations
    cityGrid[8][9] = CellType.waterPump;
    cityGrid[8][21] = CellType.waterPump;
    cityGrid[22][9] = CellType.waterPump;
    cityGrid[21][22] = CellType.waterPump;

    // Set power and water coverage based on challenge mode
    if (infrastructureRequired) {
      // Challenge mode: no coverage, must build infrastructure
      powerGrid = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => false);
      });
      waterGrid = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => false);
      });
    } else {
      // Easy mode: full coverage across entire grid
      powerGrid = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => true);
      });
      waterGrid = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => true);
      });
    }
  }

  @override
  void dispose() {
    vehicleSpawnTimer?.cancel();
    idleIncomeTimer?.cancel();
    vehicleAnimationTimer?.cancel();
    floatingTextTimer?.cancel();
    zoneGrowthTimer?.cancel();
    super.dispose();
  }

  // SIMCITY CORE SYSTEMS

  // Power grid propagation - radiates 8 squares from power plants
  void updatePowerGrid() {
    // Reset power grid
    powerGrid = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) => false);
    });

    // Find all power plants and apply coverage radius
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (cityGrid[row][col] == CellType.powerPlant && buildingActive[row][col]) {
          // Apply power coverage in 10-square radius (only if active)
          _applyPowerCoverage(row, col, 10);
        }
      }
    }
  }

  void _applyPowerCoverage(int centerRow, int centerCol, int radius) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        // Calculate distance from power plant (Chebyshev distance - diagonals count as 1)
        int distance = max((row - centerRow).abs(), (col - centerCol).abs());
        if (distance <= radius) {
          powerGrid[row][col] = true;
        }
      }
    }
  }

  // Water grid propagation - radiates 8 squares from water pumps
  void updateWaterGrid() {
    // Reset water grid
    waterGrid = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) => false);
    });

    // Find all water pumps and apply coverage radius
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (cityGrid[row][col] == CellType.waterPump && buildingActive[row][col]) {
          // Apply water coverage in 10-square radius (only if active)
          _applyWaterCoverage(row, col, 10);
        }
      }
    }
  }

  void _applyWaterCoverage(int centerRow, int centerCol, int radius) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        // Calculate distance from water pump (Chebyshev distance - diagonals count as 1)
        int distance = max((row - centerRow).abs(), (col - centerCol).abs());
        if (distance <= radius) {
          waterGrid[row][col] = true;
        }
      }
    }
  }

  // Service coverage calculation
  void updateServiceCoverage() {
    // Reset coverage
    policeCoverage = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) => 0);
    });
    fireCoverage = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) => 0);
    });
    hospitalCoverage = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) => 0);
    });
    schoolCoverage = List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) => 0);
    });

    // Apply coverage for all service buildings (larger radius like SimCity)
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (cityGrid[row][col] == CellType.policeStation) {
          _applyCoverage(policeCoverage, row, col, 8);
        }
        if (cityGrid[row][col] == CellType.fireStation) {
          _applyCoverage(fireCoverage, row, col, 8);
        }
        if (cityGrid[row][col] == CellType.hospital) {
          _applyCoverage(hospitalCoverage, row, col, 9);
        }
        if (cityGrid[row][col] == CellType.school) {
          _applyCoverage(schoolCoverage, row, col, 8);
        }
      }
    }
  }

  void _applyCoverage(List<List<int>> coverageGrid, int centerRow, int centerCol, int radius) {
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        double distance = sqrt(pow(row - centerRow, 2) + pow(col - centerCol, 2));
        if (distance <= radius) {
          int coverage = ((1 - distance / radius) * 10).round();
          coverageGrid[row][col] = max(coverageGrid[row][col], coverage);
        }
      }
    }
  }

  // Calculate city statistics based on coverage and ordinances
  void updateCityStatistics() {
    // Calculate average coverage across all tiles
    double avgPoliceCoverage = 0;
    double avgSchoolCoverage = 0;
    double avgFireCoverage = 0;
    double avgHealthCoverage = 0;
    int count = 0;

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        avgPoliceCoverage += policeCoverage[row][col];
        avgSchoolCoverage += schoolCoverage[row][col];
        avgFireCoverage += fireCoverage[row][col];
        avgHealthCoverage += hospitalCoverage[row][col];
        count++;
      }
    }

    if (count > 0) {
      avgPoliceCoverage /= count;
      avgSchoolCoverage /= count;
      avgFireCoverage /= count;
      avgHealthCoverage /= count;
    }

    // Crime rate (0-100, higher = more crime)
    // Base crime starts at 50, good police coverage reduces it
    crimeRate = 50.0 - (avgPoliceCoverage * 5);

    // Ordinance effects on crime
    if (ordinances['neighborhood_watch'] == true) crimeRate -= 15;
    if (ordinances['legalize_gambling'] == true) crimeRate += 20;

    // Clamp to 0-100
    crimeRate = crimeRate.clamp(0, 100);

    // Education rate (0-100, higher = better)
    educationRate = 50.0 + (avgSchoolCoverage * 5);
    if (ordinances['pro_reading_campaign'] == true) educationRate += 10;
    educationRate = educationRate.clamp(0, 100);

    // Health rate (0-100, higher = better)
    healthRate = 50.0 + (avgHealthCoverage * 5);
    if (ordinances['free_clinics'] == true) healthRate += 10;
    healthRate = healthRate.clamp(0, 100);

    // Fire protection rate (0-100, higher = better)
    fireProtectionRate = 50.0 + (avgFireCoverage * 5);
    if (ordinances['smoke_detector_program'] == true) fireProtectionRate += 10;
    fireProtectionRate = fireProtectionRate.clamp(0, 100);
  }

  // Building evolution - buildings automatically upgrade over time
  void processBuildingEvolution() {
    if (gameSpeed == GameSpeed.paused) return; // Don't evolve buildings when paused

    final random = Random();

    // Adjust evolution rate based on game speed
    int attempts = 2; // Medium speed default
    if (gameSpeed == GameSpeed.slow) attempts = 1;
    if (gameSpeed == GameSpeed.fast) attempts = 4;

    // Try to evolve a few buildings each tick
    for (int attempt = 0; attempt < attempts; attempt++) {
      int row = random.nextInt(gridSize);
      int col = random.nextInt(gridSize);

      final cellType = cityGrid[row][col];

      // Check if building can evolve to next tier
      CellType? nextTier;
      int populationRequired = 0;

      // Residential evolution: house → apartment → condo
      if (cellType == CellType.residentialLow && population >= 30) {
        nextTier = CellType.residentialMedium;
      } else if (cellType == CellType.residentialMedium && population >= 100) {
        nextTier = CellType.residentialHigh;
      }
      // Commercial evolution: shop → office → skyscraper
      else if (cellType == CellType.commercialLow && population >= 40) {
        nextTier = CellType.commercialMedium;
      } else if (cellType == CellType.commercialMedium && population >= 120) {
        nextTier = CellType.commercialHigh;
      }
      // Industrial evolution: warehouse → factory → heavy industry
      else if (cellType == CellType.industrialLow && population >= 35) {
        nextTier = CellType.industrialMedium;
      } else if (cellType == CellType.industrialMedium && population >= 110) {
        nextTier = CellType.industrialHigh;
      }

      // Evolve the building if conditions met
      if (nextTier != null) {
        // Need good services to upgrade
        int services = policeCoverage[row][col] + fireCoverage[row][col] +
                      hospitalCoverage[row][col] + schoolCoverage[row][col];
        if (services >= 5 && powerGrid[row][col] && waterGrid[row][col]) {
          setState(() {
            cityGrid[row][col] = nextTier!;
            population += 5; // Population boost from denser building
            addFloatingText('⬆️', row.toDouble(), col.toDouble());
          });
        }
      }
    }
  }

  // Zone growth - zones develop into buildings based on conditions
  void processZoneGrowth() {
    if (gameSpeed == GameSpeed.paused) return; // Don't grow zones when paused

    final random = Random();

    // Adjust growth rate based on game speed
    int attempts = 1; // Medium speed default - slow gradual growth
    if (gameSpeed == GameSpeed.slow) attempts = 1;
    if (gameSpeed == GameSpeed.fast) attempts = 3;

    // Try to grow a few zones each tick
    for (int attempt = 0; attempt < attempts; attempt++) {
      int row = random.nextInt(gridSize);
      int col = random.nextInt(gridSize);

      final cellType = cityGrid[row][col];

      // Check if it's a zone that can grow
      if (cellType == CellType.residentialZone ||
          cellType == CellType.commercialZone ||
          cellType == CellType.industrialZone) {

        // Check growth requirements
        if (!_canZoneGrow(row, col, cellType)) continue;

        // Grow the zone
        setState(() {
          if (cellType == CellType.residentialZone) {
            cityGrid[row][col] = _getResidentialBuilding();
            constructionProgress[row][col] = 0.0; // Start construction animation
            population += 20;
            residentialDemand -= 10;
            checkAchievements();
          } else if (cellType == CellType.commercialZone) {
            cityGrid[row][col] = _getCommercialBuilding();
            constructionProgress[row][col] = 0.0; // Start construction animation
            population += 10;
            commercialDemand -= 10;
            checkAchievements();
          } else if (cellType == CellType.industrialZone) {
            cityGrid[row][col] = _getIndustrialBuilding();
            constructionProgress[row][col] = 0.0; // Start construction animation
            population += 6;
            industrialDemand -= 10;
            checkAchievements();
          }

          addFloatingText('🏗️', row.toDouble(), col.toDouble());
          updatePowerGrid();
          updateWaterGrid();
        });
      }
    }

    // Update RCI demand based on city composition
    _updateRCIDemand();
  }

  bool _canZoneGrow(int row, int col, CellType zoneType) {
    // Must have power and water
    if (!powerGrid[row][col]) {
      print('Zone at ($row,$col) cannot grow: NO POWER');
      return false;
    }
    if (!waterGrid[row][col]) {
      print('Zone at ($row,$col) cannot grow: NO WATER');
      return false;
    }

    // Must be near a road (or infrastructure placed on roads)
    bool nearRoad = false;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        int r = row + dr;
        int c = col + dc;
        if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
          final adjCell = cityGrid[r][c];
          // Roads include: streets, power lines, water pipes, and combined infrastructure
          if (adjCell == CellType.street ||
              adjCell == CellType.powerLine ||
              adjCell == CellType.waterPipe ||
              adjCell == CellType.powerLineAndWaterPipe) {
            nearRoad = true;
            break;
          }
        }
      }
    }
    if (!nearRoad) {
      print('Zone at ($row,$col) cannot grow: NO NEARBY ROAD');
      return false;
    }

    // Check demand
    if (zoneType == CellType.residentialZone && residentialDemand <= 0) {
      print('Zone at ($row,$col) cannot grow: NO RESIDENTIAL DEMAND');
      return false;
    }
    if (zoneType == CellType.commercialZone && commercialDemand <= 0) {
      print('Zone at ($row,$col) cannot grow: NO COMMERCIAL DEMAND');
      return false;
    }
    if (zoneType == CellType.industrialZone && industrialDemand <= 0) {
      print('Zone at ($row,$col) cannot grow: NO INDUSTRIAL DEMAND');
      return false;
    }

    return true;
  }

  CellType _getResidentialBuilding() {
    // Simple for now - could be based on land value, density, etc.
    if (population < 50) return CellType.residentialLow;
    if (population < 150) return CellType.residentialMedium;
    return CellType.residentialHigh;
  }

  CellType _getCommercialBuilding() {
    if (population < 50) return CellType.commercialLow;
    if (population < 150) return CellType.commercialMedium;
    return CellType.commercialHigh;
  }

  CellType _getIndustrialBuilding() {
    if (population < 50) return CellType.industrialLow;
    if (population < 150) return CellType.industrialMedium;
    return CellType.industrialHigh;
  }

  void _updateRCIDemand() {
    // Count different building types
    int residential = 0;
    int commercial = 0;
    int industrial = 0;

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final cell = cityGrid[row][col];
        if (cell == CellType.residentialLow ||
            cell == CellType.residentialMedium ||
            cell == CellType.residentialHigh) {
          residential++;
        } else if (cell == CellType.commercialLow ||
                   cell == CellType.commercialMedium ||
                   cell == CellType.commercialHigh) {
          commercial++;
        } else if (cell == CellType.industrialLow ||
                   cell == CellType.industrialMedium ||
                   cell == CellType.industrialHigh) {
          industrial++;
        }
      }
    }

    // SimCity-style demand calculation (rebalanced for better gameplay)
    // Residential demand: More jobs = more demand, more housing = less demand
    // Add base demand of +30 to ensure early growth
    residentialDemand = (((commercial + industrial) * 3.0 - residential * 2.0) + 30).clamp(-100, 100);

    // Commercial demand: More residents = more demand, more shops = less demand
    // Add base demand of +20 to ensure early growth
    commercialDemand = ((residential * 2.0 - commercial * 3.0) + 20).clamp(-100, 100);

    // Industrial demand: More commercial = more demand (supply chain), more factories = less demand
    // Add base demand of +25 to ensure early growth
    industrialDemand = ((commercial * 2.0 - industrial * 3.0) + 25).clamp(-100, 100);
  }

  // ACHIEVEMENT SYSTEM
  void checkAchievements() {
    // First City - place first building
    if (population >= 10 && !unlockedAchievements.contains('first_city')) {
      unlockAchievement('first_city', '🏘️ First City!', 'You built your first residential building!');
    }

    // Small Town - reach 50 population
    if (population >= 50 && !unlockedAchievements.contains('small_town')) {
      unlockAchievement('small_town', '🏘️ Small Town', 'Population reached 50!');
    }

    // Growing City - reach 100 population
    if (population >= 100 && !unlockedAchievements.contains('growing_city')) {
      unlockAchievement('growing_city', '🏙️ Growing City', 'Population reached 100!');
    }

    // Metropolis - reach 200 population
    if (population >= 200 && !unlockedAchievements.contains('metropolis')) {
      unlockAchievement('metropolis', '🌆 Metropolis!', 'Population reached 200!');
    }

    // Green City - build 10 parks
    int parkCount = 0;
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final cell = cityGrid[row][col];
        if (cell == CellType.park || cell == CellType.playground ||
            cell == CellType.fountain || cell == CellType.garden || cell == CellType.statue) {
          parkCount++;
        }
      }
    }
    if (parkCount >= 10 && !unlockedAchievements.contains('green_city')) {
      unlockAchievement('green_city', '🌳 Green City', 'Built 10 parks!');
    }

    // Wealthy - reach 10,000 coins
    if (coins >= 10000 && !unlockedAchievements.contains('wealthy')) {
      unlockAchievement('wealthy', '💰 Wealthy!', 'Reached 10,000 coins!');
    }

    // Tycoon - reach 50,000 coins
    if (coins >= 50000 && !unlockedAchievements.contains('tycoon')) {
      unlockAchievement('tycoon', '💎 Tycoon!', 'Reached 50,000 coins!');
    }
  }

  void unlockAchievement(String id, String title, String description) {
    unlockedAchievements.add(id);
    achievementNotifications.add('$title\n$description');

    // Award bonus for achievements
    coins += 500;

    // Remove notification after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        achievementNotifications.removeWhere((n) => n == '$title\n$description');
      });
    });
  }

  // RANDOM EVENTS SYSTEM
  void triggerRandomEvent() {
    final random = Random();

    // 30% chance of event per cycle
    if (random.nextDouble() > 0.3) return;

    // List of possible events
    List<Map<String, dynamic>> events = [
      {
        'name': '🎉 City Festival',
        'description': 'Tourism boom!',
        'effect': () {
          coins += 1000;
          addFloatingText('+\$1000', gridSize / 2, gridSize / 2);
        },
      },
      {
        'name': '💼 Business Investment',
        'description': 'New investors!',
        'effect': () {
          coins += 1500;
          addFloatingText('+\$1500', gridSize / 2, gridSize / 2);
        },
      },
      {
        'name': '📈 Economic Boom',
        'description': 'Productivity up!',
        'effect': () {
          coins += 2000;
          population += 5;
          addFloatingText('📈 Boom!', gridSize / 2, gridSize / 2);
        },
      },
      {
        'name': '🌧️ Heavy Rain',
        'description': 'Minor damage',
        'effect': () {
          coins -= 500;
          addFloatingText('-\$500', gridSize / 2, gridSize / 2);
        },
      },
      {
        'name': '🚧 Infrastructure Repair',
        'description': 'Maintenance costs',
        'effect': () {
          coins -= 800;
          addFloatingText('-\$800', gridSize / 2, gridSize / 2);
        },
      },
      {
        'name': '👥 Population Surge',
        'description': 'New residents!',
        'effect': () {
          population += 10;
          addFloatingText('+10 👥', gridSize / 2, gridSize / 2);
        },
      },
    ];

    // Pick random event
    final event = events[random.nextInt(events.length)];

    // Show event notification
    achievementNotifications.add('${event['name']}\n${event['description']}');

    // Apply event effect
    setState(() {
      event['effect']();
    });

    // Remove notification after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        achievementNotifications.removeWhere((n) => n == '${event['name']}\n${event['description']}');
      });
    });
  }

  void spawnVehicle() {
    if (gameSpeed == GameSpeed.paused) return; // Don't spawn vehicles when paused

    final random = Random();

    // Find all street cells
    List<Point<int>> streetCells = [];
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (cityGrid[row][col] == CellType.street) {
          streetCells.add(Point(row, col));
        }
      }
    }

    if (streetCells.isEmpty) return;

    // Pick a random street cell
    final streetCell = streetCells[random.nextInt(streetCells.length)];

    final vehicleEmojis = ['🚗', '🚕', '🚙', '🚌', '🚎'];

    // Create the vehicle with random direction
    final newVehicle = Vehicle(
      gridRow: streetCell.x.toDouble(),
      gridCol: streetCell.y.toDouble(),
      color: Color.fromRGBO(
        random.nextInt(200) + 55,
        random.nextInt(200) + 55,
        random.nextInt(200) + 55,
        1,
      ),
      reward: random.nextInt(15) + 10,
      emoji: vehicleEmojis[random.nextInt(vehicleEmojis.length)],
    )..direction = random.nextInt(4); // Random initial direction

    setState(() {
      vehicles.add(newVehicle);
    });

    // Remove THIS specific vehicle after 8 seconds if not tapped
    Future.delayed(const Duration(seconds: 8), () {
      if (!newVehicle.tapped) {
        setState(() {
          vehicles.remove(newVehicle);
        });
      }
    });
  }

  void animateVehicles() {
    if (gameSpeed == GameSpeed.paused) return; // Don't animate vehicles when paused

    setState(() {
      List<Vehicle> vehiclesToRemove = [];

      for (var vehicle in vehicles) {
        if (vehicle.tapped) continue; // Don't move tapped vehicles

        // Update bobbing animation
        vehicle.animationOffset += 0.1;
        if (vehicle.animationOffset > 1.0) {
          vehicle.animationOffset = 0.0;
        }

        // Move vehicle in current direction
        double newRow = vehicle.gridRow;
        double newCol = vehicle.gridCol;

        switch (vehicle.direction) {
          case 0: // Right
            newCol += vehicle.moveSpeed;
            break;
          case 1: // Down
            newRow += vehicle.moveSpeed;
            break;
          case 2: // Left
            newCol -= vehicle.moveSpeed;
            break;
          case 3: // Up
            newRow -= vehicle.moveSpeed;
            break;
        }

        // Check if new position is valid (within grid and on street)
        int checkRow = newRow.round();
        int checkCol = newCol.round();

        if (checkRow < 0 || checkRow >= gridSize || checkCol < 0 || checkCol >= gridSize) {
          // Out of bounds - remove vehicle
          vehiclesToRemove.add(vehicle);
          continue;
        }

        // Check if still on street
        if (cityGrid[checkRow][checkCol] == CellType.street) {
          // Move vehicle
          vehicle.gridRow = newRow;
          vehicle.gridCol = newCol;
        } else {
          // Try to turn at intersection
          bool turned = false;

          // Try all four directions
          for (int dir = 0; dir < 4; dir++) {
            if (dir == vehicle.direction) continue; // Skip current direction

            int testRow = vehicle.gridRow.round();
            int testCol = vehicle.gridCol.round();

            switch (dir) {
              case 0: testCol++; break; // Right
              case 1: testRow++; break; // Down
              case 2: testCol--; break; // Left
              case 3: testRow--; break; // Up
            }

            if (testRow >= 0 && testRow < gridSize && testCol >= 0 && testCol < gridSize &&
                cityGrid[testRow][testCol] == CellType.street) {
              vehicle.direction = dir;
              turned = true;
              break;
            }
          }

          if (!turned) {
            // Can't turn, remove vehicle
            vehiclesToRemove.add(vehicle);
          }
        }
      }

      // Remove vehicles that went off-road or out of bounds
      for (var vehicle in vehiclesToRemove) {
        vehicles.remove(vehicle);
      }
    });
  }

  void generateIdleIncome() {
    if (gameSpeed == GameSpeed.paused) return; // Don't generate income/expenses when paused

    int income = 0;
    int expenses = 0;

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final cell = cityGrid[row][col];
        final building = buildings[cell];

        if (building != null) {
          int buildingIncome = building.income;

          // Only developed buildings generate tax income (not zones or infrastructure)
          if (buildingIncome > 0) {
            // Buildings with power and water generate more income
            int multiplier = 1;
            if (powerGrid[row][col]) multiplier++;
            if (waterGrid[row][col]) multiplier++;

            income += buildingIncome * multiplier;
          } else if (buildingIncome < 0) {
            // Negative income = maintenance cost
            // Only charge maintenance for active infrastructure
            bool isInfrastructure = cell == CellType.powerPlant || cell == CellType.waterPump;
            if (!isInfrastructure || buildingActive[row][col]) {
              expenses += buildingIncome.abs();
            }
          }
        }
      }
    }

    // Add ordinance costs/income
    for (var entry in ordinances.entries) {
      if (entry.value == true) {
        int cost = ordinanceCosts[entry.key] ?? 0;
        if (cost < 0) {
          // Negative cost = income (like gambling)
          income += cost.abs();
        } else {
          // Positive cost = expense
          expenses += cost;
        }
      }
    }

    // Apply net income
    int netIncome = income - expenses;

    if (netIncome != 0) {
      setState(() {
        coins += netIncome;
        monthlyIncome = income;
        monthlyExpenses = expenses;
      });
    }
  }

  void tapVehicle(Vehicle vehicle) {
    if (!vehicle.tapped) {
      setState(() {
        vehicle.tapped = true;
        coins += vehicle.reward;
        vehicles.remove(vehicle);

        // Show floating text and gain XP
        addFloatingText('+${vehicle.reward}', vehicle.gridRow.toDouble(), vehicle.gridCol.toDouble());
        gainExperience(5);
        saveGame(); // Save after earning coins
      });
    }
  }

  // Save game to localStorage
  Future<void> saveGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save basic stats
      await prefs.setInt('coins', coins);
      await prefs.setInt('population', population);
      await prefs.setInt('playerLevel', playerLevel);
      await prefs.setInt('experience', experience);
      await prefs.setInt('experienceToNextLevel', experienceToNextLevel);

      // Save city grid (convert enums to indices)
      List<String> gridData = [];
      for (var row in cityGrid) {
        gridData.add(row.map((cell) => cell.index.toString()).join(','));
      }
      await prefs.setStringList('cityGrid', gridData);

      // Save building upgrades
      List<String> upgradesData = [];
      for (var row in buildingUpgrades) {
        upgradesData.add(row.map((level) => level.toString()).join(','));
      }
      await prefs.setStringList('buildingUpgrades', upgradesData);

      // Save building active state
      List<String> activeData = [];
      for (var row in buildingActive) {
        activeData.add(row.map((active) => active ? '1' : '0').join(','));
      }
      await prefs.setStringList('buildingActive', activeData);

      print('Game saved successfully!');
    } catch (e) {
      print('Error saving game: $e');
    }
  }

  // Load game from localStorage
  Future<void> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load basic stats
      final savedCoins = prefs.getInt('coins');
      if (savedCoins != null) {
        setState(() {
          coins = savedCoins;
          population = prefs.getInt('population') ?? 0;
          playerLevel = prefs.getInt('playerLevel') ?? 1;
          experience = prefs.getInt('experience') ?? 0;
          experienceToNextLevel = prefs.getInt('experienceToNextLevel') ?? 300;
        });

        // Load city grid
        final gridData = prefs.getStringList('cityGrid');
        if (gridData != null && gridData.length == gridSize) {
          List<List<CellType>> loadedGrid = [];
          for (var rowData in gridData) {
            List<CellType> row = rowData.split(',').map((indexStr) {
              int index = int.parse(indexStr);
              return CellType.values[index];
            }).toList();
            loadedGrid.add(row);
          }
          cityGrid = loadedGrid;
        }

        // Load building upgrades
        final upgradesData = prefs.getStringList('buildingUpgrades');
        if (upgradesData != null && upgradesData.length == gridSize) {
          List<List<int>> loadedUpgrades = [];
          for (var rowData in upgradesData) {
            List<int> row = rowData.split(',').map((str) => int.parse(str)).toList();
            loadedUpgrades.add(row);
          }
          buildingUpgrades = loadedUpgrades;
        }

        // Load building active state
        final activeData = prefs.getStringList('buildingActive');
        if (activeData != null && activeData.length == gridSize) {
          List<List<bool>> loadedActive = [];
          for (var rowData in activeData) {
            List<bool> row = rowData.split(',').map((str) => str == '1').toList();
            loadedActive.add(row);
          }
          buildingActive = loadedActive;
        }

        print('Game loaded successfully!');
      }
    } catch (e) {
      print('Error loading game: $e');
    }
  }

  // Start a new game
  Future<void> newGame() async {
    try {
      // Clear saved game data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Reset all state to initial values
      setState(() {
        coins = 5000;
        population = 0;
        playerLevel = 1;
        experience = 0;
        experienceToNextLevel = 300;
        vehicles.clear();
        floatingTexts.clear();
        selectedBuilding = null;
        bulldozerMode = false;
        infoMode = false;
        undergroundView = false;
        gameSpeed = GameSpeed.medium;
        expandedCategory = null;
        residentialDemand = 50.0;
        commercialDemand = 30.0;
        industrialDemand = 40.0;
        monthlyIncome = 0;
        monthlyExpenses = 0;
        elapsedSeconds = 0;
        gameCycle = 0;
        gameStartTime = DateTime.now();

        // Re-initialize city grid
        initializeCity();

        // Re-initialize all grids
        buildingUpgrades = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => 0);
        });
        buildingActive = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => true);
        });
        constructionProgress = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => 1.0);
        });
        powerGrid = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => false);
        });
        waterGrid = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => false);
        });
        policeCoverage = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => 0);
        });
        fireCoverage = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => 0);
        });
        hospitalCoverage = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => 0);
        });
        schoolCoverage = List.generate(gridSize, (row) {
          return List.generate(gridSize, (col) => 0);
        });
      });

      print('New game started!');
    } catch (e) {
      print('Error starting new game: $e');
    }
  }

  void placeBuilding(int row, int col) {
    print('placeBuilding called: row=$row, col=$col, selectedBuilding=$selectedBuilding, cellType=${cityGrid[row][col]}');

    // Info mode - show building info
    if (infoMode) {
      showBuildingInfo(context, row, col);
      return;
    }

    // Bulldozer mode - demolish building
    if (bulldozerMode) {
      demolishBuilding(row, col);
      return;
    }

    // Toggle infrastructure on/off when clicked (if no building selected)
    if (selectedBuilding == null) {
      final cellType = cityGrid[row][col];
      if (cellType == CellType.powerPlant || cellType == CellType.waterPump) {
        setState(() {
          buildingActive[row][col] = !buildingActive[row][col];
          updatePowerGrid();
          updateWaterGrid();
          addFloatingText(buildingActive[row][col] ? '⚡ ON' : '⏸️ OFF', row.toDouble(), col.toDouble());
        });
        saveGame();
        return;
      }
    }

    // In SimCity, buildings auto-upgrade, not manual upgrades
    // So we skip this check

    // Place new building/zone/infrastructure
    if (selectedBuilding != null) {
      final currentCell = cityGrid[row][col];

      // Check if placement is allowed
      bool canPlace = false;
      bool convertToCombined = false;

      // Allow on empty cells
      if (currentCell == CellType.empty) {
        canPlace = true;
      }
      // Allow power/water infrastructure on streets (SimCity style!)
      else if (currentCell == CellType.street) {
        if (selectedBuilding == CellType.powerLine ||
            selectedBuilding == CellType.waterPipe) {
          canPlace = true;
        }
      }
      // Allow crossing power and water lines!
      else if (currentCell == CellType.powerLine && selectedBuilding == CellType.waterPipe) {
        canPlace = true;
        convertToCombined = true;
      }
      else if (currentCell == CellType.waterPipe && selectedBuilding == CellType.powerLine) {
        canPlace = true;
        convertToCombined = true;
      }

      if (!canPlace) {
        print('Cannot place here!');
        return;
      }

      final building = buildings[selectedBuilding]!;

      // Check if unlocked
      if (!isBuildingUnlocked(selectedBuilding!)) {
        print('Building not unlocked!');
        return;
      }

      if (coins >= building.cost) {
        print('Placing building! Cost: ${building.cost}, Coins: $coins');
        setState(() {
          coins -= building.cost;

          // If crossing infrastructure, convert to combined type
          if (convertToCombined) {
            cityGrid[row][col] = CellType.powerLineAndWaterPipe;
          } else {
            cityGrid[row][col] = selectedBuilding!;
          }

          // Zones don't add population directly (buildings that grow from them do)
          final isZone = selectedBuilding == CellType.residentialZone ||
                        selectedBuilding == CellType.commercialZone ||
                        selectedBuilding == CellType.industrialZone;

          if (!isZone) {
            population += 5; // Small population boost for infrastructure buildings
          }

          // Gain XP for placing
          gainExperience(5);

          // Update grids after placing infrastructure
          updatePowerGrid();
          updateWaterGrid();
          updateServiceCoverage();
        });
        saveGame(); // Save after placing building
      } else {
        print('Not enough coins! Need: ${building.cost}, Have: $coins');
      }
    } else {
      print('Cannot place: selectedBuilding=$selectedBuilding, cellEmpty=${cityGrid[row][col] == CellType.empty}');
    }
  }

  void demolishBuilding(int row, int col) {
    final cellType = cityGrid[row][col];

    // Can only demolish buildings (not streets or empty cells)
    if (cellType == CellType.empty || cellType == CellType.street) {
      return;
    }

    setState(() {
      cityGrid[row][col] = CellType.empty;
      buildingUpgrades[row][col] = 0; // Reset upgrade level
      population -= 15;

      // Show demolish effect
      addFloatingText('💥', row.toDouble(), col.toDouble());
    });
    saveGame(); // Save after demolishing
  }

  void showBuildingInfo(BuildContext context, int row, int col) {
    final cellType = cityGrid[row][col];

    // Get building name and details
    String title = '';
    String emoji = '';
    List<String> details = [];

    if (cellType == CellType.empty) {
      title = 'Empty Land';
      emoji = '🟩';
      details.add('This land is empty and ready for development.');
    } else if (cellType == CellType.street) {
      title = 'Street';
      emoji = '🛣️';
      details.add('Roads allow zones to develop and vehicles to travel.');
    } else {
      final building = buildings[cellType];
      if (building != null) {
        title = building.name;
        emoji = building.emoji;

        // Income/expense info
        if (building.income > 0) {
          int baseIncome = building.income;
          int multiplier = 1;
          if (powerGrid[row][col]) multiplier++;
          if (waterGrid[row][col]) multiplier++;
          int actualIncome = baseIncome * multiplier;

          details.add('💰 Income: \$${actualIncome}/cycle (base: \$${baseIncome})');
          if (multiplier > 1) {
            details.add('   ${powerGrid[row][col] ? "⚡ Powered" : ""} ${waterGrid[row][col] ? "💧 Watered" : ""}');
          }
        } else if (building.income < 0) {
          details.add('💸 Maintenance: \$${building.income.abs()}/cycle');
        } else {
          details.add('💰 Income: \$0/cycle');
        }

        // Cost info
        details.add('🏗️ Build cost: \$${building.cost}');

        // Upgrade level
        final upgradeLevel = buildingUpgrades[row][col];
        if (upgradeLevel > 0) {
          details.add('⭐ Upgrade level: $upgradeLevel');
        }

        // Utilities
        details.add('');
        details.add('Utilities:');
        details.add('  ${powerGrid[row][col] ? "✅" : "❌"} Power');
        details.add('  ${waterGrid[row][col] ? "✅" : "❌"} Water');

        // Services
        if (policeCoverage[row][col] > 0 || fireCoverage[row][col] > 0 ||
            hospitalCoverage[row][col] > 0 || schoolCoverage[row][col] > 0) {
          details.add('');
          details.add('Service Coverage:');
          if (policeCoverage[row][col] > 0) {
            details.add('  🚓 Police: ${policeCoverage[row][col]}/10');
          }
          if (fireCoverage[row][col] > 0) {
            details.add('  🚒 Fire: ${fireCoverage[row][col]}/10');
          }
          if (hospitalCoverage[row][col] > 0) {
            details.add('  🏥 Hospital: ${hospitalCoverage[row][col]}/10');
          }
          if (schoolCoverage[row][col] > 0) {
            details.add('  🏫 School: ${schoolCoverage[row][col]}/10');
          }
        }
      }
    }

    // Show dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location: ($row, $col)'),
                SizedBox(height: 8),
                ...details.map((detail) => Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(detail),
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void upgradeBuilding(int row, int col) {
    final cellType = cityGrid[row][col];
    if (cellType == CellType.empty || cellType == CellType.street) return;

    final currentUpgrade = buildingUpgrades[row][col];
    if (currentUpgrade >= 2) return; // Max 3 levels (0, 1, 2)

    final building = buildings[cellType]!;
    final upgradeCost = (building.cost * 0.5 * (currentUpgrade + 1)).round();

    if (coins >= upgradeCost) {
      setState(() {
        coins -= upgradeCost;
        buildingUpgrades[row][col]++;
        addFloatingText('⬆️ +${(building.income * 0.5 * (currentUpgrade + 1)).round()}/s', row.toDouble(), col.toDouble());
      });
    }
  }

  bool isBuildingUnlocked(CellType buildingType) {
    final requiredLevel = buildingUnlockLevel[buildingType] ?? 1;
    return playerLevel >= requiredLevel;
  }

  int getBuildingIncome(CellType cellType, int row, int col) {
    final baseIncome = buildings[cellType]!.income;
    final upgradeLevel = buildingUpgrades[row][col];

    // Each upgrade adds 50% to base income
    return (baseIncome * (1 + upgradeLevel * 0.5)).round();
  }

  void gainExperience(int xp) {
    setState(() {
      experience += xp;

      // Level up check
      while (experience >= experienceToNextLevel) {
        experience -= experienceToNextLevel;
        playerLevel++;
        experienceToNextLevel = (experienceToNextLevel * 2.0).round(); // Doubles each level

        // Show level up notification
        addFloatingText('🎉 LEVEL $playerLevel!', gridSize / 2, gridSize / 2);
      }
    });
  }

  void addFloatingText(String text, double row, double col) {
    // Convert grid position to screen position (approximate)
    final floatingText = FloatingText(
      text: text,
      startX: col * 50, // Approximate cell width
      startY: row * 50, // Approximate cell height
    );

    setState(() {
      floatingTexts.add(floatingText);
    });

    // Remove after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        floatingTexts.remove(floatingText);
      });
    });
  }

  void animateFloatingTexts() {
    if (floatingTexts.isEmpty) return;

    setState(() {
      for (var text in floatingTexts) {
        final age = DateTime.now().difference(text.createdAt).inMilliseconds;
        text.offsetY = -(age / 10.0); // Float up
        text.opacity = 1.0 - (age / 2000.0); // Fade out over 2 seconds
      }
    });
  }

  void _showBudgetDialog(BuildContext context) {
    // Calculate detailed budget breakdown
    Map<String, int> incomeBreakdown = {};
    Map<String, int> expenseBreakdown = {};

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final cell = cityGrid[row][col];
        final building = buildings[cell];

        if (building != null) {
          int buildingIncome = building.income;

          // Only developed buildings generate tax income (not zones or infrastructure)
          if (buildingIncome > 0) {
            // Buildings with power and water generate more income
            int multiplier = 1;
            if (powerGrid[row][col]) multiplier++;
            if (waterGrid[row][col]) multiplier++;

            int income = buildingIncome * multiplier;
            incomeBreakdown[building.name] = (incomeBreakdown[building.name] ?? 0) + income;
          } else if (buildingIncome < 0) {
            // Negative income = maintenance cost
            int expense = buildingIncome.abs();
            expenseBreakdown[building.name] = (expenseBreakdown[building.name] ?? 0) + expense;
          }
        }
      }
    }

    int totalIncome = incomeBreakdown.values.fold(0, (sum, val) => sum + val);
    int totalExpenses = expenseBreakdown.values.fold(0, (sum, val) => sum + val);
    int netIncome = totalIncome - totalExpenses;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text('📊 Budget Report'),
              Spacer(),
              Text(
                netIncome >= 0 ? '+\$$netIncome' : '-\$$netIncome.abs()',
                style: TextStyle(
                  color: netIncome >= 0 ? Colors.green : Colors.red,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Income section
                Text(
                  '💰 Income: \$$totalIncome',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 8),
                ...incomeBreakdown.entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('${entry.key}: +\$${entry.value}'),
                  );
                }).toList(),
                SizedBox(height: 16),
                // Expenses section
                Text(
                  '💸 Expenses: \$$totalExpenses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                ...expenseBreakdown.entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('${entry.key}: -\$${entry.value}'),
                  );
                }).toList(),
                if (expenseBreakdown.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('No expenses'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF87CEEB),
      body: SafeArea(
        child: Row(
          children: [
            // Main game area (header + city grid)
            Expanded(
              child: Column(
                children: [
                  // Header with stats
                  Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            coins += 1000;
                          });
                        },
                        child: _buildStatChip('💰 \$$coins', Color(0xFFFFC107)),
                      ),
                      GestureDetector(
                        onTap: () {
                          _showBudgetDialog(context);
                        },
                        child: _buildStatChip('📊 +\$$monthlyIncome/-\$$monthlyExpenses', monthlyIncome >= monthlyExpenses ? Color(0xFF4CAF50) : Color(0xFFF44336)),
                      ),
                      _buildStatChip('👥 $population', Color(0xFF4CAF50)),
                      _buildStatChip('🕐 ${_formatTime(elapsedSeconds)} | Month $gameCycle', Color(0xFF9C27B0)),
                      // Speed control buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSpeedButton('⏸', GameSpeed.paused, Color(0xFFFF9800)),
                          SizedBox(width: 4),
                          _buildSpeedButton('▶', GameSpeed.slow, Color(0xFF4CAF50)),
                          SizedBox(width: 4),
                          _buildSpeedButton('▶▶', GameSpeed.medium, Color(0xFF2196F3)),
                          SizedBox(width: 4),
                          _buildSpeedButton('▶▶▶', GameSpeed.fast, Color(0xFF9C27B0)),
                        ],
                      ),
                      // Underground view toggle button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            undergroundView = !undergroundView;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: undergroundView ? Color(0xFF00BCD4) : Color(0xFF616161),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Text(
                            undergroundView ? '🔼 Surface' : '🔽 Underground',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      // Infrastructure challenge toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            infrastructureRequired = !infrastructureRequired;
                            // Reinitialize grids based on new mode
                            initializeCity();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: infrastructureRequired ? Color(0xFFFF5722) : Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Text(
                            infrastructureRequired ? '⚡ Challenge' : '⚡ Easy',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      // Save button
                      GestureDetector(
                        onTap: () {
                          saveGame();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Game saved!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Text(
                            '💾 Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      // New Game button
                      GestureDetector(
                        onTap: () {
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Start New Game?'),
                                content: Text('This will reset all progress and start a new city. Are you sure?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      newGame();
                                    },
                                    child: Text('New Game', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFFF5722),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Text(
                            '🆕 New Game',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      // Zoom controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                zoomLevel = (zoomLevel - 0.2).clamp(0.5, 3.0);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Color(0xFF9C27B0),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Text(
                                '🔍-',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                zoomLevel = (zoomLevel + 0.2).clamp(0.5, 3.0);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Color(0xFF9C27B0),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Text(
                                '🔍+',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  // XP Progress Bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: experience / experienceToNextLevel,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFEB3B), Color(0xFFFFC107)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // RCI Demand Bars (SimCity style) - Grouped together
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDemandBar('R', residentialDemand, Color(0xFF4CAF50)),
                      SizedBox(width: 2),
                      _buildDemandBar('C', commercialDemand, Color(0xFF2196F3)),
                      SizedBox(width: 2),
                      _buildDemandBar('I', industrialDemand, Color(0xFFFFEB3B)),
                    ],
                  ),
                  SizedBox(height: 8),
                  // City Statistics Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatBar('Crime', crimeRate, Colors.red, inverted: true), // Lower is better
                      _buildStatBar('Education', educationRate, Colors.blue),
                      _buildStatBar('Health', healthRate, Colors.green),
                      _buildStatBar('Fire Safety', fireProtectionRate, Colors.orange),
                      // Ordinances button
                      GestureDetector(
                        onTap: () {
                          _showOrdinancesDialog(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF9C27B0),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Text(
                            '📜 Ordinances',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // City view
            Expanded(
              child: Stack(
                children: [
                  // City grid - zoomed to fit
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Transform.scale(
                          scale: zoomLevel,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridSize,
                              crossAxisSpacing: 1,
                              mainAxisSpacing: 1,
                            ),
                            itemCount: gridSize * gridSize,
                            itemBuilder: (context, index) {
                              final row = index ~/ gridSize;
                              final col = index % gridSize;
                              final cellType = cityGrid[row][col];

                              return GestureDetector(
                                onTap: () => placeBuilding(row, col),
                                child: Stack(
                                  children: [
                                    _buildCell(cellType, row, col),
                                    // Upgrade stars indicator
                                    if (cellType != CellType.empty &&
                                        cellType != CellType.street &&
                                        buildingUpgrades[row][col] > 0)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '⭐' * buildingUpgrades[row][col],
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                // Vehicles overlay - pointer events pass through to grid
                IgnorePointer(
                    ignoring: false,
                    child: Center(
                      child: Transform.scale(
                        scale: zoomLevel,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: LayoutBuilder(
                            builder: (context, constraints) {
                              final gridWidth = constraints.maxWidth;
                              final cellSize = gridWidth / gridSize;

                              return Stack(
                                children: vehicles.map((vehicle) {
                                  final left = vehicle.gridCol * cellSize;
                                  final top = vehicle.gridRow * cellSize;

                                  return Positioned(
                                    left: left,
                                    top: top,
                                    width: cellSize,
                                    height: cellSize,
                                    child: GestureDetector(
                                      onTap: () => tapVehicle(vehicle),
                                      child: _buildVehicleWidget(vehicle),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                  // Floating texts overlay
                  ...floatingTexts.map((text) {
                    return Positioned(
                      left: text.startX,
                      top: text.startY + text.offsetY,
                      child: Opacity(
                        opacity: text.opacity.clamp(0.0, 1.0),
                        child: Text(
                          text.text,
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(2, 2),
                                blurRadius: 3,
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                  // Achievement/Event notifications - top center overlay
                  ...achievementNotifications.asMap().entries.map((entry) {
                    int index = entry.key;
                    String notification = entry.value;
                    return Positioned(
                      top: 80.0 + (index * 100), // Stack multiple notifications
                      left: MediaQuery.of(context).size.width / 2 - 150,
                      child: Container(
                        width: 300,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: Offset(0, 4),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Text(
                          notification,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
                ],
              ),
            ),

            // Building selection menu - CATEGORIZED (Now on the right side)
            Container(
              width: 100,
              decoration: BoxDecoration(
                color: Color(0xFF263238),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: Offset(-2, 0),
                    blurRadius: 4,
                  )
                ],
              ),
              child: expandedCategory == null
                  ? _buildCategoryMenu()
                  : _buildItemMenu(),
            ),
          ],
        ),
      ),
    );
  }

  // Build the category menu (main view) - Vertical layout for side panel
  Widget _buildCategoryMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Info mode
          _buildCategoryButton(
            label: 'Info',
            emoji: '🔍',
            isActive: infoMode,
            onTap: () {
              setState(() {
                infoMode = !infoMode;
                bulldozerMode = false;
                selectedBuilding = null;
              });
            },
          ),
          // Bulldozer
          _buildCategoryButton(
            label: 'Doze',
            emoji: '🚧',
            isActive: bulldozerMode,
            onTap: () {
              setState(() {
                bulldozerMode = !bulldozerMode;
                infoMode = false;
                selectedBuilding = null;
              });
            },
          ),
          // Zones
          _buildCategoryButton(
            label: 'Zones',
            emoji: '🏘️',
            onTap: () {
              setState(() {
                expandedCategory = 'zones';
                bulldozerMode = false;
                infoMode = false;
              });
            },
          ),
          // Utilities
          _buildCategoryButton(
            label: 'Utils',
            emoji: '⚡',
            onTap: () {
              setState(() {
                expandedCategory = 'utilities';
                bulldozerMode = false;
                infoMode = false;
              });
            },
          ),
          // Services
          _buildCategoryButton(
            label: 'Svc',
            emoji: '🚓',
            onTap: () {
              setState(() {
                expandedCategory = 'services';
                bulldozerMode = false;
                infoMode = false;
              });
            },
          ),
          // Special
          _buildCategoryButton(
            label: 'Park',
            emoji: '🌳',
            onTap: () {
              setState(() {
                expandedCategory = 'special';
                bulldozerMode = false;
                infoMode = false;
              });
            },
          ),
        ],
      ),
    );
  }

  // Build a category button - Compact vertical style
  Widget _buildCategoryButton({
    required String label,
    required String emoji,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFF4CAF50) : Color(0xFF37474F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Color(0xFF66BB6A) : Color(0xFF546E7A),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Build the item menu (expanded category view) - Vertical scrolling list
  Widget _buildItemMenu() {
    // Determine which items to show based on expandedCategory
    List<CellType> items = [];

    if (expandedCategory == 'zones') {
      items = [
        CellType.residentialZone,
        CellType.commercialZone,
        CellType.industrialZone,
      ];
    } else if (expandedCategory == 'utilities') {
      items = [
        CellType.powerPlant,
        CellType.waterPump,
      ];
    } else if (expandedCategory == 'services') {
      items = [
        CellType.policeStation,
        CellType.fireStation,
        CellType.hospital,
        CellType.school,
        CellType.library,
        CellType.museum,
        CellType.stadium,
        CellType.cityHall,
      ];
    } else if (expandedCategory == 'special') {
      items = [
        CellType.park,
        CellType.playground,
        CellType.fountain,
        CellType.garden,
        CellType.statue,
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: Column(
        children: [
          // Back button
          GestureDetector(
            onTap: () {
              setState(() {
                expandedCategory = null;
                selectedBuilding = null;
                bulldozerMode = false;
                infoMode = false;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF37474F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 16),
            ),
          ),
          SizedBox(height: 6),
          // Items in this category (vertical scroll)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: items.map((cellType) {
                  final building = buildings[cellType]!;
                  final isSelected = selectedBuilding == cellType;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: GestureDetector(
                      onTap: () {
                        print('Selected building: ${building.name}');
                        setState(() {
                          selectedBuilding = cellType;
                          bulldozerMode = false;
                          infoMode = false;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? building.topColor : Color(0xFF37474F),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? Colors.white : Color(0xFF546E7A),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              building.emoji,
                              style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(height: 2),
                            Text(
                              building.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 1),
                            Text(
                              '\$${building.cost}',
                              style: TextStyle(
                                color: Color(0xFFFFC107),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(CellType cellType, int row, int col) {
    // UNDERGROUND VIEW - Show only power/water infrastructure
    if (undergroundView) {
      if (cellType == CellType.powerPlant || cellType == CellType.powerLine) {
        // Show power infrastructure in bright yellow/orange
        return Container(
          decoration: BoxDecoration(
            color: powerGrid[row][col] ? Color(0xFFFFEB3B) : Color(0xFF9E9E9E),
            border: Border.all(color: Color(0xFFF57F17), width: 1),
          ),
          child: Center(
            child: Text('⚡', style: TextStyle(fontSize: 8)),
          ),
        );
      } else if (cellType == CellType.waterPump || cellType == CellType.waterPipe) {
        // Show water infrastructure in bright blue
        return Container(
          decoration: BoxDecoration(
            color: waterGrid[row][col] ? Color(0xFF00BCD4) : Color(0xFF9E9E9E),
            border: Border.all(color: Color(0xFF006064), width: 1),
          ),
          child: Center(
            child: Text('💧', style: TextStyle(fontSize: 8)),
          ),
        );
      } else if (cellType == CellType.powerLineAndWaterPipe) {
        // Show combined infrastructure with gradient/split view
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                powerGrid[row][col] ? Color(0xFFFFEB3B) : Color(0xFF9E9E9E),
                waterGrid[row][col] ? Color(0xFF00BCD4) : Color(0xFF9E9E9E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Color(0xFF616161), width: 1),
          ),
          child: Center(
            child: Text('⚡💧', style: TextStyle(fontSize: 6)),
          ),
        );
      } else if (cellType == CellType.street) {
        // Show streets dimmed
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF616161),
            border: Border.all(color: Color(0xFF757575), width: 0.5),
          ),
        );
      } else {
        // Everything else is dimmed/hidden
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFF424242).withOpacity(0.3),
            border: Border.all(color: Color(0xFF616161), width: 0.5),
          ),
        );
      }
    }

    // SURFACE VIEW - Normal rendering
    if (cellType == CellType.street) {
      // Street cell - dark gray asphalt
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFF424242),
          border: Border.all(color: Color(0xFF757575), width: 0.5),
        ),
        child: Center(
          child: Container(
            width: 2,
            height: 2,
            decoration: BoxDecoration(
              color: Color(0xFFFFEB3B).withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else if (cellType == CellType.powerLine) {
      // Power line - show as street with power indicator
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFF424242), // Street color
          border: Border.all(color: Color(0xFFF57F17), width: 1), // Power color border
        ),
        child: Center(
          child: Text('⚡', style: TextStyle(fontSize: 8)),
        ),
      );
    } else if (cellType == CellType.waterPipe) {
      // Water pipe - show as street with water indicator
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFF424242), // Street color
          border: Border.all(color: Color(0xFF00BCD4), width: 1), // Water color border
        ),
        child: Center(
          child: Text('💧', style: TextStyle(fontSize: 8)),
        ),
      );
    } else if (cellType == CellType.powerLineAndWaterPipe) {
      // Combined power and water - show as street with both indicators
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFF424242), // Street color
          gradient: LinearGradient(
            colors: [Color(0xFFF57F17).withOpacity(0.3), Color(0xFF00BCD4).withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Color(0xFF9C27B0), width: 1), // Purple border for combined
        ),
        child: Center(
          child: Text('⚡💧', style: TextStyle(fontSize: 6)),
        ),
      );
    } else if (cellType == CellType.empty) {
      // Empty lot - grass
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFF66BB6A),
          border: Border.all(color: Color(0xFF4CAF50), width: 0.5),
        ),
      );
    } else {
      // Building - Check if it should use isometric 3D or simple flat style
      final building = buildings[cellType]!;

      // Check if it's a park
      bool isPark = cellType == CellType.park ||
                    cellType == CellType.playground ||
                    cellType == CellType.fountain ||
                    cellType == CellType.garden ||
                    cellType == CellType.statue;

      // Use simple flat blocks for zones and infrastructure only
      bool isZoneOrInfra = cellType == CellType.residentialZone ||
                           cellType == CellType.commercialZone ||
                           cellType == CellType.industrialZone ||
                           cellType == CellType.powerPlant ||
                           cellType == CellType.waterPump;

      if (isPark) {
        // Use special isometric park rendering
        return _buildIsometricPark(building, cellType, row, col);
      } else if (isZoneOrInfra) {
        return _buildSimpleBuilding(building, cellType, row, col);
      } else {
        // Use isometric 3D for actual developed buildings
        return _buildIsometricBuilding(building, cellType, row, col);
      }
    }
  }

  Widget _buildSimpleBuilding(Building building, CellType cellType, int row, int col) {
    // Simple flat style for zones and infrastructure
    // Check if this is an inactive infrastructure building
    bool isInfrastructure = cellType == CellType.powerPlant || cellType == CellType.waterPump;
    bool isActive = buildingActive[row][col];

    return Container(
      decoration: BoxDecoration(
        color: (isInfrastructure && !isActive)
            ? building.topColor.withOpacity(0.4)
            : building.topColor,
        border: Border.all(color: building.sideColor, width: 1),
      ),
      child: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: (isInfrastructure && !isActive) ? 0.5 : 1.0,
              child: Text(
                building.emoji,
                style: TextStyle(fontSize: 8),
              ),
            ),
          ),
          // Show OFF indicator for inactive infrastructure
          if (isInfrastructure && !isActive)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text('⏸️', style: TextStyle(fontSize: 4)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIsometricBuilding(Building building, CellType cellType, int row, int col) {
    // Isometric 3D building with height variation and construction animation
    double progress = constructionProgress[row][col];
    return Container(
      color: Color(0xFF66BB6A), // Grass background
      child: CustomPaint(
        painter: IsometricBuildingPainter(building, cellType, progress),
        child: SizedBox.expand(),
      ),
    );
  }

  Widget _buildIsometricPark(Building building, CellType cellType, int row, int col) {
    // Isometric 3D park - lower profile, green, organic
    return Container(
      color: Color(0xFF66BB6A), // Grass background
      child: CustomPaint(
        painter: IsometricParkPainter(building, cellType),
        child: SizedBox.expand(),
      ),
    );
  }

  Widget _buildVehicleWidget(Vehicle vehicle) {
    return Center(
      child: Transform.translate(
        offset: Offset(0, sin(vehicle.animationOffset * 2 * pi) * 2),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: vehicle.color,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                offset: Offset(1, 1),
                blurRadius: 2,
              )
            ],
          ),
          child: Center(
            child: Text(
              vehicle.emoji,
              style: TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: Offset(2, 2),
            blurRadius: 2,
          )
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          shadows: [
            Shadow(
              color: Colors.white,
              offset: Offset(0.5, 0.5),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedButton(String text, GameSpeed speed, Color color) {
    bool isSelected = gameSpeed == speed;
    return GestureDetector(
      onTap: () {
        setState(() {
          gameSpeed = speed;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: Offset(2, 2),
              blurRadius: 2,
            )
          ] : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildDemandBar(String label, double demand, Color color) {
    // Demand ranges from -100 to +100
    // Positive = high demand (bar goes up)
    // Negative = low demand (bar goes down)
    final demandNormalized = (demand / 100.0).clamp(-1.0, 1.0);
    final isPositive = demandNormalized > 0;
    final barHeight = demandNormalized.abs() * 50; // Max 50px (was 20px) - taller bars

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
          ),
        ),
        SizedBox(height: 2),
        Container(
          width: 20, // Fixed width - skinnier bars
          height: 60, // Taller container (was 24px)
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Positive demand bar (grows upward)
              Container(
                height: isPositive ? barHeight : 0,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Center line
              Container(height: 2, color: Colors.white.withOpacity(0.8)), // Thicker, more visible line
              // Negative demand bar (grows downward)
              Container(
                height: !isPositive ? barHeight : 0,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBar(String label, double value, Color color, {bool inverted = false}) {
    // Value ranges from 0 to 100
    // For inverted stats (like crime), we want low values to be good (green) and high to be bad (red)
    final normalizedValue = (value / 100.0).clamp(0.0, 1.0);

    // Determine color based on value and whether it's inverted
    Color barColor;
    if (inverted) {
      // For crime: low = good (green), high = bad (red)
      if (normalizedValue < 0.3) barColor = Colors.green;
      else if (normalizedValue < 0.6) barColor = Colors.orange;
      else barColor = Colors.red;
    } else {
      // For education/health/fire: high = good (green), low = bad (red)
      if (normalizedValue > 0.7) barColor = Colors.green;
      else if (normalizedValue > 0.4) barColor = Colors.orange;
      else barColor = Colors.red;
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 9,
            shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
          ),
        ),
        SizedBox(height: 2),
        Container(
          width: 60,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: normalizedValue,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        Text(
          '${value.toInt()}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            shadows: [Shadow(color: Colors.black, offset: Offset(1, 1))],
          ),
        ),
      ],
    );
  }

  void _showOrdinancesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('City Ordinances', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Container(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Enact or repeal city ordinances. Each has benefits and costs.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 16),
                      ..._buildOrdinancesList(setDialogState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildOrdinancesList(StateSetter setDialogState) {
    final ordinanceInfo = {
      'legalize_gambling': {'name': '🎰 Legalize Gambling', 'effect': '+\$50/month, +20 crime'},
      'neighborhood_watch': {'name': '👮 Neighborhood Watch', 'effect': '-15 crime, \$30/month'},
      'pro_reading_campaign': {'name': '📚 Pro-Reading Campaign', 'effect': '+10 education, \$25/month'},
      'free_clinics': {'name': '🏥 Free Clinics', 'effect': '+10 health, \$40/month'},
      'smoke_detector_program': {'name': '🚨 Smoke Detector Program', 'effect': '+10 fire safety, \$20/month'},
      'energy_conservation': {'name': '⚡ Energy Conservation', 'effect': 'Reduces power costs'},
      'tourism_promotion': {'name': '🗽 Tourism Promotion', 'effect': '+commercial demand, +income, \$35/month'},
      'recycling_program': {'name': '♻️ Recycling Program', 'effect': 'Future: -pollution, \$30/month'},
    };

    return ordinanceInfo.entries.map((entry) {
      final key = entry.key;
      final info = entry.value;
      final isActive = ordinances[key] ?? false;
      final cost = ordinanceCosts[key] ?? 0;

      return Card(
        margin: EdgeInsets.symmetric(vertical: 4),
        child: CheckboxListTile(
          title: Text(info['name']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(info['effect']!, style: TextStyle(fontSize: 11)),
          value: isActive,
          onChanged: (bool? value) {
            setState(() {
              ordinances[key] = value ?? false;
              updateCityStatistics(); // Recalculate stats immediately
            });
            setDialogState(() {}); // Update dialog UI
          },
        ),
      );
    }).toList();
  }
}

// Custom painter for isometric buildings
class IsometricBuildingPainter extends CustomPainter {
  final Building building;
  final CellType cellType;
  final double constructionProgress; // 0.0 to 1.0

  IsometricBuildingPainter(this.building, this.cellType, this.constructionProgress);

  double _getBuildingHeightMultiplier() {
    // Different heights for different building types
    switch (cellType) {
      // Small buildings
      case CellType.residentialLow:
        return 0.6;
      case CellType.commercialLow:
        return 0.7;
      case CellType.industrialLow:
        return 0.5;

      // Medium buildings
      case CellType.residentialMedium:
        return 1.0;
      case CellType.commercialMedium:
        return 1.1;
      case CellType.industrialMedium:
        return 0.8;

      // Tall buildings
      case CellType.residentialHigh:
        return 1.5;
      case CellType.commercialHigh:
        return 1.7;
      case CellType.industrialHigh:
        return 1.2;

      // Services - medium height
      case CellType.policeStation:
      case CellType.fireStation:
      case CellType.hospital:
      case CellType.school:
      case CellType.library:
      case CellType.museum:
        return 0.9;

      // Large services
      case CellType.stadium:
        return 1.3;
      case CellType.cityHall:
        return 1.4;

      default:
        return 1.0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Building dimensions with height variation and construction animation
    final centerX = size.width / 2;
    final baseY = size.height * 0.85; // Bottom of building
    final buildingWidth = size.width * 0.75;
    final heightMultiplier = _getBuildingHeightMultiplier();
    final fullBuildingHeight = size.height * 1.2 * heightMultiplier; // Variable height!
    final buildingHeight = fullBuildingHeight * constructionProgress; // Animate construction!

    // Calculate key points for isometric building
    final topCenterY = baseY - buildingHeight;

    // Top face (roof) - diamond shape
    final topPath = Path();
    topPath.moveTo(centerX, topCenterY); // Top point
    topPath.lineTo(centerX + buildingWidth / 3, topCenterY + buildingHeight * 0.15); // Right
    topPath.lineTo(centerX, topCenterY + buildingHeight * 0.25); // Bottom center of roof
    topPath.lineTo(centerX - buildingWidth / 3, topCenterY + buildingHeight * 0.15); // Left
    topPath.close();

    paint.color = building.topColor;
    canvas.drawPath(topPath, paint);

    // Left face (darker wall)
    final leftPath = Path();
    leftPath.moveTo(centerX - buildingWidth / 3, topCenterY + buildingHeight * 0.15);
    leftPath.lineTo(centerX, topCenterY + buildingHeight * 0.25);
    leftPath.lineTo(centerX, baseY);
    leftPath.lineTo(centerX - buildingWidth / 3, baseY - buildingHeight * 0.1);
    leftPath.close();

    paint.color = building.sideColor;
    canvas.drawPath(leftPath, paint);

    // Right face (lighter wall)
    final rightPath = Path();
    rightPath.moveTo(centerX + buildingWidth / 3, topCenterY + buildingHeight * 0.15);
    rightPath.lineTo(centerX, topCenterY + buildingHeight * 0.25);
    rightPath.lineTo(centerX, baseY);
    rightPath.lineTo(centerX + buildingWidth / 3, baseY - buildingHeight * 0.1);
    rightPath.close();

    // Right face is brighter than left
    paint.color = Color.lerp(building.topColor, building.sideColor, 0.4)!;
    canvas.drawPath(rightPath, paint);

    // Draw windows on the building faces - proper parallelograms
    paint.style = PaintingStyle.fill;
    paint.color = Color(0xFF64B5F6); // Brighter blue windows

    // Windows on left face (4 rows of 1 window each)
    final windowWidth = buildingWidth / 6;
    final windowHeight = buildingHeight / 10;

    for (int floor = 0; floor < 4; floor++) {
      final windowY = baseY - buildingHeight * 0.8 + (floor * buildingHeight * 0.22);

      // Left face window - proper parallelogram following wall perspective
      final leftWindowPath = Path();
      // Top-left corner
      leftWindowPath.moveTo(centerX - buildingWidth / 4.5, windowY);
      // Top-right corner (toward center)
      leftWindowPath.lineTo(centerX - buildingWidth / 8, windowY + windowHeight * 0.2);
      // Bottom-right corner
      leftWindowPath.lineTo(centerX - buildingWidth / 8, windowY + windowHeight);
      // Bottom-left corner
      leftWindowPath.lineTo(centerX - buildingWidth / 4.5, windowY + windowHeight * 0.8);
      leftWindowPath.close();
      canvas.drawPath(leftWindowPath, paint);

      // Window frame (outline)
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      paint.color = Color(0xFF0D47A1);
      canvas.drawPath(leftWindowPath, paint);
      paint.style = PaintingStyle.fill;
      paint.color = Color(0xFF64B5F6);
    }

    // Windows on right face (4 rows of 1 window each)
    for (int floor = 0; floor < 4; floor++) {
      final windowY = baseY - buildingHeight * 0.8 + (floor * buildingHeight * 0.22);

      // Right face window - proper parallelogram following wall perspective
      final rightWindowPath = Path();
      // Top-left corner (toward center)
      rightWindowPath.moveTo(centerX + buildingWidth / 8, windowY + windowHeight * 0.2);
      // Top-right corner
      rightWindowPath.lineTo(centerX + buildingWidth / 4.5, windowY);
      // Bottom-right corner
      rightWindowPath.lineTo(centerX + buildingWidth / 4.5, windowY + windowHeight * 0.8);
      // Bottom-left corner
      rightWindowPath.lineTo(centerX + buildingWidth / 8, windowY + windowHeight);
      rightWindowPath.close();
      canvas.drawPath(rightWindowPath, paint);

      // Window frame (outline)
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      paint.color = Color(0xFF0D47A1);
      canvas.drawPath(rightWindowPath, paint);
      paint.style = PaintingStyle.fill;
      paint.color = Color(0xFF64B5F6);
    }

    // Black outlines for definition
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = Colors.black;

    canvas.drawPath(topPath, paint);
    canvas.drawPath(leftPath, paint);
    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Park painter - low profile, green, organic 3D isometric parks
class IsometricParkPainter extends CustomPainter {
  final Building building;
  final CellType cellType;

  IsometricParkPainter(this.building, this.cellType);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Park dimensions - much lower than buildings!
    final centerX = size.width / 2;
    final baseY = size.height * 0.75; // Lower base
    final parkWidth = size.width * 0.8; // Slightly wider
    final parkHeight = size.height * 0.3; // Much shorter than buildings!

    // Calculate key points
    final topCenterY = baseY - parkHeight;

    // Top face - organic diamond shape
    final topPath = Path();
    topPath.moveTo(centerX, topCenterY); // Top point
    topPath.lineTo(centerX + parkWidth / 2.5, topCenterY + parkHeight * 0.2); // Right
    topPath.lineTo(centerX, topCenterY + parkHeight * 0.35); // Bottom
    topPath.lineTo(centerX - parkWidth / 2.5, topCenterY + parkHeight * 0.2); // Left
    topPath.close();

    // Lighter green for top
    paint.color = building.topColor;
    canvas.drawPath(topPath, paint);

    // Left face - darker green
    final leftPath = Path();
    leftPath.moveTo(centerX - parkWidth / 2.5, topCenterY + parkHeight * 0.2);
    leftPath.lineTo(centerX, topCenterY + parkHeight * 0.35);
    leftPath.lineTo(centerX, baseY);
    leftPath.lineTo(centerX - parkWidth / 2.5, baseY - parkHeight * 0.15);
    leftPath.close();

    paint.color = building.sideColor;
    canvas.drawPath(leftPath, paint);

    // Right face - medium green
    final rightPath = Path();
    rightPath.moveTo(centerX + parkWidth / 2.5, topCenterY + parkHeight * 0.2);
    rightPath.lineTo(centerX, topCenterY + parkHeight * 0.35);
    rightPath.lineTo(centerX, baseY);
    rightPath.lineTo(centerX + parkWidth / 2.5, baseY - parkHeight * 0.15);
    rightPath.close();

    paint.color = Color.lerp(building.topColor, building.sideColor, 0.5)!;
    canvas.drawPath(rightPath, paint);

    // Black outlines for definition
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = Colors.black.withOpacity(0.6); // Softer outline for parks

    canvas.drawPath(topPath, paint);
    canvas.drawPath(leftPath, paint);
    canvas.drawPath(rightPath, paint);

    // Draw emoji on top of park
    final textPainter = TextPainter(
      text: TextSpan(
        text: building.emoji,
        style: TextStyle(
          fontSize: size.width * 0.4, // Large emoji
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        topCenterY - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
