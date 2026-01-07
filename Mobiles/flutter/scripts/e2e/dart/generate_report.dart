import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:args/args.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('path',
        abbr: 'p',
        help:
            'Path to the test results folder containing result.yml and screenshots/',
        mandatory: true);

  try {
    final results = parser.parse(arguments);
    final basePath = results['path'];

    if (!Directory(basePath).existsSync()) {
      print('Error: Directory does not exist: $basePath');
      exit(1);
    }

    final resultPath = path.join(basePath, 'result.yml');
    if (!File(resultPath).existsSync()) {
      print('Error: result.yml not found in: $basePath');
      exit(1);
    }

    final screenshotsPath = path.join(basePath, 'screenshots');
    if (!Directory(screenshotsPath).existsSync()) {
      print('Error: screenshots directory not found in: $basePath');
      exit(1);
    }

    await generateHtml(resultPath, basePath);
    print(
        'Report generated successfully at: ${path.join(basePath, "simple_results.html")}');
  } catch (e) {
    print('Error: ${e.toString()}');
    print('\nUsage:');
    print(parser.usage);
    exit(1);
  }
}

String formatTimestamp(String stepId) {
  try {
    final parts = stepId.split('_');
    if (parts.length >= 4) {
      final timestampMs = int.parse(parts[2]);
      final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    }
  } catch (e) {
    print('Error formatting timestamp: $e');
  }
  return 'Unknown time';
}

String? extractGoalFromAiRequest(String? aiRequest) {
  if (aiRequest == null || !aiRequest.contains('Goal:')) {
    return null;
  }

  try {
    final goalStart = aiRequest.indexOf('Goal:') + 5;
    final goalEnd = aiRequest.indexOf('\n\n', goalStart);
    final goal = goalEnd == -1
        ? aiRequest.substring(goalStart).trim()
        : aiRequest.substring(goalStart, goalEnd).trim();
    return goal.replaceAll('\n', '<br>');
  } catch (e) {
    print('Error extracting goal: $e');
    return null;
  }
}

String? getScreenshotPath(String basePath, String? screenshotName) {
  if (screenshotName == null) return null;

  final fileName = path.basename(screenshotName);
  final nameWithoutExt = path.basenameWithoutExtension(fileName);
  final annotatedName = '${nameWithoutExt}_annotated.png';

  final annotatedPath = path.join(basePath, 'screenshots', annotatedName);
  final regularPath = path.join(basePath, 'screenshots', fileName);

  if (File(annotatedPath).existsSync()) {
    return 'screenshots/$annotatedName';
  } else if (File(regularPath).existsSync()) {
    return 'screenshots/$fileName';
  }
  return null;
}

Future<void> generateHtml(String resultPath, String basePath) async {
  final file = File(resultPath);
  final content = await file.readAsString();
  final data = loadYaml(content) as Map;

  final scenarios = data['scenarios'] as List? ?? [];
  final totalScenarios = scenarios.length;
  final successfulScenarios =
      scenarios.where((s) => s['isSuccess'] == true).length;

  final overallSummary = '''
    <div class="overall-summary">
      <h1>🍕 QuickPizza E2E Test Results</h1>
      <div class="test-stats">
        <div class="stat-item">
          <span class="stat-label">Total Scenarios:</span>
          <span class="stat-value">$totalScenarios</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Successful:</span>
          <span class="stat-value success-text">$successfulScenarios</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Failed:</span>
          <span class="stat-value failure-text">${totalScenarios - successfulScenarios}</span>
        </div>
      </div>
    </div>
  ''';

  final scenariosHtml = scenarios.map((scenario) {
    final scenarioId = scenario['id'] ?? 'Unknown Scenario';
    final scenarioGoal =
        (scenario['goal'] as String? ?? '').replaceAll('\n', '<br>');
    final isSuccess = scenario['isSuccess'] == true;
    final scenarioClass = isSuccess ? 'success' : 'failure';

    final histories = scenario['histories'] as List? ?? [];
    final historiesHtml = <String>[];

    for (var i = 0; i < histories.length; i++) {
      final history = histories[i];
      final historyIndex = i + 1;
      final stepsHtml = <String>[];

      final agentResults = history['agentResults'] as List? ?? [];
      for (final agentResult in agentResults) {
        final steps = agentResult['steps'] as List? ?? [];
        for (final step in steps) {
          final screenshotPath = getScreenshotPath(
              basePath, step['screenshotFilePath'] as String?);
          if (screenshotPath != null) {
            final summary =
                (step['summary'] as String? ?? '').replaceAll('\n', '<br>');
            final stepId = step['stepId'] as String? ?? 'Unknown';
            final timestamp = formatTimestamp(stepId);
            final agentCommand = step['agentCommand'] as String? ?? '';
            final goalFromRequest =
                extractGoalFromAiRequest(step['aiRequest'] as String?);

            final infoHtml = <String>[
              '<div class="timestamp">Time: $timestamp</div>',
              if (goalFromRequest != null)
                '<div class="ai-goal"><div class="goal-label">Goal:</div>$goalFromRequest</div>',
              '<div class="summary">$summary</div>',
              '<div class="technical-info">',
              '<div class="step-id">ID: $stepId</div>',
              if (agentCommand.isNotEmpty)
                '<div class="agent-command">AI Agent Command: $agentCommand</div>',
              '</div>'
            ];

            stepsHtml.add('''
              <div class="screenshot-card">
                <img src="$screenshotPath" 
                     alt="Test Screenshot" 
                     class="screenshot-image" 
                     onclick="showImage('$screenshotPath')">
                <div class="screenshot-info">
                  ${infoHtml.join('\n')}
                </div>
              </div>
            ''');
          }
        }
      }

      if (stepsHtml.isNotEmpty) {
        historiesHtml.add('''
          <div class="history-section">
            <h3 class="history-title">History $historyIndex / ${histories.length}</h3>
            <div class="screenshots-grid">
              ${stepsHtml.join('\n')}
            </div>
          </div>
        ''');
      }
    }

    return '''
      <div class="scenario-section $scenarioClass">
        <h2>Scenario: $scenarioId</h2>
        <div class="scenario-goal">$scenarioGoal</div>
        <div class="scenario-status">Status: ${isSuccess ? '✅ Success' : '❌ Failure'}</div>
        ${historiesHtml.join('\n')}
      </div>
    ''';
  }).join('\n');

  final htmlTemplate = '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>QuickPizza E2E Test Results</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
                    Oxygen, Ubuntu, Cantarell, sans-serif;
                margin: 0;
                padding: 20px;
                background: #fff5e6;
            }
            .container {
                max-width: 1200px;
                margin: 0 auto;
            }
            .overall-summary {
                background: white;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 20px;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
            }
            h1 {
                color: #e53e3e;
            }
            .test-stats {
                display: flex;
                gap: 20px;
                margin-top: 10px;
            }
            .stat-item {
                padding: 10px 20px;
                border-radius: 6px;
                background: #f8fafc;
            }
            .stat-label {
                font-weight: 500;
                color: #4a5568;
                margin-right: 8px;
            }
            .stat-value {
                font-weight: 600;
                color: #2d3748;
            }
            .success-text {
                color: #38a169;
            }
            .failure-text {
                color: #e53e3e;
            }
            .history-section {
                margin: 20px 0;
            }
            .history-title {
                color: #4a5568;
                font-size: 1.1em;
                margin: 10px 0;
                padding: 8px;
                background: #f8fafc;
                border-radius: 4px;
            }
            .screenshots-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                padding: 20px;
            }
            .screenshot-card {
                background: white;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
                padding: 15px;
                transition: transform 0.2s;
            }
            .screenshot-card:hover {
                transform: translateY(-5px);
                box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
            }
            .screenshot-image {
                width: 100%;
                height: auto;
                border-radius: 4px;
                cursor: pointer;
            }
            .screenshot-info {
                margin-top: 10px;
            }
            .screenshot-info > div {
                margin: 5px 0;
            }
            .timestamp {
                color: #666;
                font-size: 0.9em;
            }
            .technical-info {
                margin-top: 12px;
                border-top: 1px solid #e2e8f0;
                padding-top: 8px;
            }
            .step-id {
                color: #718096;
                font-size: 0.75em;
                font-family: monospace;
                margin-bottom: 8px;
            }
            .agent-command {
                color: #c53030;
                font-family: monospace;
                background: #fff5f5;
                padding: 4px 8px;
                border-radius: 4px;
                font-size: 0.9em;
            }
            .ai-goal {
                color: #2d3748;
                font-size: 0.9em;
                border-left: 3px solid #ed8936;
                padding-left: 8px;
                margin: 8px 0;
            }
            .goal-label {
                font-weight: 500;
                margin-bottom: 4px;
                color: #4a5568;
            }
            .modal {
                display: none;
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.9);
                z-index: 1000;
                justify-content: center;
                align-items: center;
            }
            .modal.active {
                display: flex;
            }
            .modal img {
                max-width: 90%;
                max-height: 90vh;
                object-fit: contain;
            }
            .scenario-section {
                margin: 20px 0;
                padding: 20px;
                border-radius: 8px;
            }
            .success {
                background: rgba(56, 161, 105, 0.1);
                border-left: 4px solid #38a169;
            }
            .failure {
                background: rgba(229, 62, 62, 0.1);
                border-left: 4px solid #e53e3e;
            }
            .scenario-goal {
                margin: 10px 0;
                padding: 10px;
                background: rgba(255, 255, 255, 0.7);
                border-radius: 4px;
            }
            .scenario-status {
                font-weight: 600;
                margin: 10px 0;
            }
            .summary {
                font-size: 0.9em;
                color: #666;
                margin-top: 10px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            $overallSummary
            <div class="scenarios">
                $scenariosHtml
            </div>
        </div>

        <div class="modal" id="imageModal" onclick="this.classList.remove('active')">
            <img id="modalImage" src="" alt="Full size screenshot">
        </div>

        <script>
            function showImage(src) {
                const modal = document.getElementById('imageModal');
                const modalImg = document.getElementById('modalImage');
                modal.classList.add('active');
                modalImg.src = src;
            }
        </script>
    </body>
    </html>
  ''';

  final outputFile = File(path.join(basePath, 'simple_results.html'));
  await outputFile.writeAsString(htmlTemplate);
}

