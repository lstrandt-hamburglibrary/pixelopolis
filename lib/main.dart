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

// Cell types - streets and buildings
enum CellType {
  street,
  empty,
  house,
  shop,
  office,
  apartment,
  factory,
  bank,
  hospital,
  school,
  park,
  skyscraper,
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
  int coins = 200;
  int population = 0;
  List<List<CellType>> cityGrid = [];
  List<Vehicle> vehicles = [];
  Timer? vehicleSpawnTimer;
  Timer? idleIncomeTimer;
  Timer? vehicleAnimationTimer;

  // Grid size - larger grid makes roads appear thinner
  final int gridSize = 16;

  // Building selection
  CellType? selectedBuilding;
  bool bulldozerMode = false;

  // Progression system
  int playerLevel = 1;
  int experience = 0;
  int experienceToNextLevel = 300; // Higher starting threshold

  // Floating text animations
  List<FloatingText> floatingTexts = [];
  Timer? floatingTextTimer;

  // Building upgrades (stores upgrade level 0-2 for each cell)
  List<List<int>> buildingUpgrades = [];

  // Unlock requirements (level needed to unlock each building)
  final Map<CellType, int> buildingUnlockLevel = {
    CellType.house: 1,
    CellType.park: 2,
    CellType.shop: 3,
    CellType.school: 4,
    CellType.office: 5,
    CellType.apartment: 6,
    CellType.hospital: 7,
    CellType.factory: 8,
    CellType.bank: 9,
    CellType.skyscraper: 10,
  };

  // Building definitions with isometric colors
  final Map<CellType, Building> buildings = {
    CellType.house: Building(
      type: CellType.house,
      name: 'House',
      emoji: '🏠',
      cost: 50,
      income: 3,
      topColor: Color(0xFF4CAF50),
      sideColor: Color(0xFF2E7D32),
    ),
    CellType.shop: Building(
      type: CellType.shop,
      name: 'Shop',
      emoji: '🏪',
      cost: 100,
      income: 8,
      topColor: Color(0xFFFF9800),
      sideColor: Color(0xFFE65100),
    ),
    CellType.office: Building(
      type: CellType.office,
      name: 'Office',
      emoji: '🏢',
      cost: 200,
      income: 20,
      topColor: Color(0xFF2196F3),
      sideColor: Color(0xFF0D47A1),
    ),
    CellType.apartment: Building(
      type: CellType.apartment,
      name: 'Apartment',
      emoji: '🏘️',
      cost: 400,
      income: 50,
      topColor: Color(0xFF9C27B0),
      sideColor: Color(0xFF4A148C),
    ),
    CellType.factory: Building(
      type: CellType.factory,
      name: 'Factory',
      emoji: '🏭',
      cost: 800,
      income: 100,
      topColor: Color(0xFF607D8B),
      sideColor: Color(0xFF263238),
    ),
    CellType.bank: Building(
      type: CellType.bank,
      name: 'Bank',
      emoji: '🏦',
      cost: 1500,
      income: 200,
      topColor: Color(0xFFFFEB3B),
      sideColor: Color(0xFFF57F17),
    ),
    CellType.hospital: Building(
      type: CellType.hospital,
      name: 'Hospital',
      emoji: '🏥',
      cost: 1200,
      income: 150,
      topColor: Color(0xFFF44336),
      sideColor: Color(0xFFB71C1C),
    ),
    CellType.school: Building(
      type: CellType.school,
      name: 'School',
      emoji: '🏫',
      cost: 600,
      income: 75,
      topColor: Color(0xFF00BCD4),
      sideColor: Color(0xFF006064),
    ),
    CellType.park: Building(
      type: CellType.park,
      name: 'Park',
      emoji: '🌳',
      cost: 150,
      income: 10,
      topColor: Color(0xFF8BC34A),
      sideColor: Color(0xFF33691E),
    ),
    CellType.skyscraper: Building(
      type: CellType.skyscraper,
      name: 'Skyscraper',
      emoji: '🏙️',
      cost: 3000,
      income: 500,
      topColor: Color(0xFF3F51B5),
      sideColor: Color(0xFF1A237E),
    ),
  };

  @override
  void initState() {
    super.initState();

    // Try to load saved game, otherwise initialize new city
    loadGame().then((_) {
      // If no saved game, initialize fresh city
      if (cityGrid.every((row) => row.every((cell) => cell == CellType.empty))) {
        initializeCity();
      }
    });

    // Initialize building upgrades grid if needed
    if (buildingUpgrades.isEmpty) {
      buildingUpgrades = List.generate(gridSize, (row) {
        return List.generate(gridSize, (col) => 0);
      });
    }

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

    // Auto-save every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (_) {
      saveGame();
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
  }

  @override
  void dispose() {
    vehicleSpawnTimer?.cancel();
    idleIncomeTimer?.cancel();
    vehicleAnimationTimer?.cancel();
    floatingTextTimer?.cancel();
    super.dispose();
  }

  void spawnVehicle() {
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
    int income = 0;

    // Bonus-giving building types
    final bonusBuildings = [
      CellType.school,
      CellType.hospital,
      CellType.skyscraper,
    ];

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final cell = cityGrid[row][col];
        if (cell != CellType.empty && cell != CellType.street) {
          // Use upgraded income
          int baseIncome = getBuildingIncome(cell, row, col);
          double multiplier = 1.0;

          // Check adjacent cells for bonus buildings
          int bonusCount = 0;
          final adjacentPositions = [
            [row - 1, col],     // top
            [row + 1, col],     // bottom
            [row, col - 1],     // left
            [row, col + 1],     // right
            [row - 1, col - 1], // top-left
            [row - 1, col + 1], // top-right
            [row + 1, col - 1], // bottom-left
            [row + 1, col + 1], // bottom-right
          ];

          for (var pos in adjacentPositions) {
            int r = pos[0];
            int c = pos[1];
            if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
              if (bonusBuildings.contains(cityGrid[r][c])) {
                bonusCount++;
              }
            }
          }

          // Each adjacent bonus building adds 20% income bonus
          if (bonusCount > 0) {
            multiplier = 1.0 + (bonusCount * 0.2);
          }

          income += (baseIncome * multiplier).round();
        }
      }
    }

    if (income > 0) {
      setState(() {
        coins += income;
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

        print('Game loaded successfully!');
      }
    } catch (e) {
      print('Error loading game: $e');
    }
  }

  void placeBuilding(int row, int col) {
    // Bulldozer mode - demolish building
    if (bulldozerMode) {
      demolishBuilding(row, col);
      return;
    }

    // Check if clicking on existing building to upgrade
    if (cityGrid[row][col] != CellType.empty && cityGrid[row][col] != CellType.street) {
      upgradeBuilding(row, col);
      return;
    }

    // Place new building
    if (selectedBuilding != null && cityGrid[row][col] == CellType.empty) {
      final building = buildings[selectedBuilding]!;

      // Check if unlocked
      if (!isBuildingUnlocked(selectedBuilding!)) {
        return;
      }

      if (coins >= building.cost) {
        setState(() {
          coins -= building.cost;
          cityGrid[row][col] = selectedBuilding!;
          population += 15;
          selectedBuilding = null;

          // Gain XP for placing building
          gainExperience(10);
        });
        saveGame(); // Save after placing building
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF87CEEB),
      body: SafeArea(
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
                      _buildStatChip('💰 $coins', Color(0xFFFFC107)),
                      _buildStatChip('⭐ Lv $playerLevel', Color(0xFFE91E63)),
                      _buildStatChip('👥 $population', Color(0xFF4CAF50)),
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
                ],
              ),
            ),

            // City view
            Expanded(
              child: Stack(
                children: [
                  // City grid
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
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
                  // Vehicles overlay - pointer events pass through to grid
                  IgnorePointer(
                    ignoring: false,
                    child: Center(
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
                ],
              ),
            ),

            // Building selection menu
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Color(0xFF263238),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: Offset(0, -2),
                    blurRadius: 4,
                  )
                ],
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                children: [
                  // Bulldozer button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        bulldozerMode = !bulldozerMode;
                        if (bulldozerMode) {
                          selectedBuilding = null; // Deselect building when enabling bulldozer
                        }
                      });
                    },
                    child: Container(
                      width: 85,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: bulldozerMode
                              ? [Color(0xFFFF5722), Color(0xFFD84315)] // Active: red/orange
                              : [Color(0xFF757575), Color(0xFF424242)], // Inactive: gray
                        ),
                        border: Border.all(
                          color: bulldozerMode ? Colors.yellow : Colors.black,
                          width: bulldozerMode ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🚜',
                            style: TextStyle(fontSize: 28),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bulldozer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                          Text(
                            bulldozerMode ? 'ACTIVE' : 'Demolish',
                            style: TextStyle(
                              color: bulldozerMode ? Colors.yellow : Colors.white,
                              fontSize: 9,
                              fontWeight: bulldozerMode ? FontWeight.bold : FontWeight.normal,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Building buttons
                  ...buildings.entries.map((entry) {
                  final building = entry.value;
                  final isSelected = selectedBuilding == entry.key;
                  final canAfford = coins >= building.cost;
                  final isUnlocked = isBuildingUnlocked(entry.key);
                  final requiredLevel = buildingUnlockLevel[entry.key] ?? 1;

                  return GestureDetector(
                    onTap: (canAfford && isUnlocked)
                        ? () {
                            setState(() {
                              bulldozerMode = false; // Disable bulldozer when selecting building
                              selectedBuilding = isSelected ? null : entry.key;
                            });
                          }
                        : null,
                    child: Container(
                      width: 85,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: !isUnlocked
                              ? [Color(0xFF424242), Color(0xFF212121)] // Locked: very dark
                              : isSelected
                                  ? [Color(0xFFFFC107), Color(0xFFF57F17)] // Selected: gold
                                  : canAfford
                                      ? [building.topColor, building.sideColor] // Can afford: building colors
                                      : [Color(0xFF616161), Color(0xFF424242)], // Can't afford: gray
                        ),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.black,
                          width: isSelected ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                building.emoji,
                                style: TextStyle(
                                  fontSize: 28,
                                  color: isUnlocked ? null : Colors.white.withOpacity(0.3),
                                ),
                              ),
                              if (!isUnlocked)
                                Text(
                                  '🔒',
                                  style: TextStyle(fontSize: 22),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            building.name,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                          Text(
                            isUnlocked ? '💰 ${building.cost}' : '🔒 Lv $requiredLevel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                        ],
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
    );
  }

  Widget _buildCell(CellType cellType, int row, int col) {
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
    } else if (cellType == CellType.empty) {
      // Empty lot - grass
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFF66BB6A),
          border: Border.all(color: Color(0xFF4CAF50), width: 0.5),
        ),
      );
    } else {
      // Building - TRUE isometric 3D pixel art style
      final building = buildings[cellType]!;
      return _buildIsometricBuilding(building);
    }
  }

  Widget _buildIsometricBuilding(Building building) {
    // Isometric building with windows, no emoji overlay
    return Container(
      color: Color(0xFF66BB6A), // Grass background
      child: CustomPaint(
        painter: IsometricBuildingPainter(building),
        child: SizedBox.expand(), // Ensures CustomPaint fills the cell
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
}

// Custom painter for isometric buildings
class IsometricBuildingPainter extends CustomPainter {
  final Building building;

  IsometricBuildingPainter(this.building);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Building dimensions - TALLER for more 3D effect
    final centerX = size.width / 2;
    final baseY = size.height * 0.85; // Bottom of building
    final buildingWidth = size.width * 0.75;
    final buildingHeight = size.height * 1.2; // MUCH taller!

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

    // Draw windows on the building faces (LARGER and MORE VISIBLE)
    paint.style = PaintingStyle.fill;
    paint.color = Color(0xFF64B5F6); // Brighter blue windows

    // Windows on left face (4 rows of 1 window each)
    final windowWidth = buildingWidth / 5;
    final windowHeight = buildingHeight / 8;

    for (int floor = 0; floor < 4; floor++) {
      final windowY = baseY - buildingHeight * 0.8 + (floor * buildingHeight * 0.22);

      // Left face window (skewed perspective) - LARGER
      final leftWindowPath = Path();
      leftWindowPath.moveTo(centerX - buildingWidth / 4.5, windowY);
      leftWindowPath.lineTo(centerX - buildingWidth / 8, windowY + windowHeight * 0.25);
      leftWindowPath.lineTo(centerX - buildingWidth / 8, windowY + windowHeight * 0.75);
      leftWindowPath.lineTo(centerX - buildingWidth / 4.5, windowY + windowHeight);
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

      // Right face window (skewed perspective) - LARGER
      final rightWindowPath = Path();
      rightWindowPath.moveTo(centerX + buildingWidth / 4.5, windowY);
      rightWindowPath.lineTo(centerX + buildingWidth / 8, windowY + windowHeight * 0.25);
      rightWindowPath.lineTo(centerX + buildingWidth / 8, windowY + windowHeight * 0.75);
      rightWindowPath.lineTo(centerX + buildingWidth / 4.5, windowY + windowHeight);
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
