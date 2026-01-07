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

String formatTimestamp(int? timestampMs) {
  if (timestampMs == null || timestampMs == 0) {
    return 'Unknown time';
  }
  try {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  } catch (e) {
    print('Error formatting timestamp: $e');
    return 'Unknown time';
  }
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

/// Parses the summary text and extracts structured components
Map<String, String?> parseSummary(String summary) {
  final result = <String, String?>{
    'imageDescription': null,
    'memo': null,
    'actionDone': null,
    'feedback': null,
    'fulfillmentPercent': null,
    'prompt': null,
    'explanation': null,
  };

  final lines = summary.split('\n');
  for (final line in lines) {
    final trimmedLine = line.trim();
    if (trimmedLine.startsWith('image description:')) {
      result['imageDescription'] =
          trimmedLine.substring('image description:'.length).trim();
    } else if (trimmedLine.startsWith('memo:')) {
      result['memo'] = trimmedLine.substring('memo:'.length).trim();
    } else if (trimmedLine.startsWith('action done:')) {
      result['actionDone'] =
          trimmedLine.substring('action done:'.length).trim();
    } else if (trimmedLine.startsWith('feedback:')) {
      result['feedback'] = trimmedLine.substring('feedback:'.length).trim();
    } else if (trimmedLine.startsWith('fulfillmentPercent:')) {
      result['fulfillmentPercent'] =
          trimmedLine.substring('fulfillmentPercent:'.length).trim();
    } else if (trimmedLine.startsWith('prompt:')) {
      result['prompt'] = trimmedLine.substring('prompt:'.length).trim();
    } else if (trimmedLine.startsWith('explanation:')) {
      result['explanation'] =
          trimmedLine.substring('explanation:'.length).trim();
    }
  }

  return result;
}

/// Returns a badge HTML for the action type
String getActionBadge(String? action) {
  if (action == null || action.isEmpty) {
    return '<span class="action-badge action-unknown">No Action</span>';
  }

  final actionLower = action.toLowerCase();
  String badgeClass;
  String icon;

  if (actionLower.contains('goal achieved')) {
    badgeClass = 'action-success';
    icon = '✅';
  } else if (actionLower.contains('failed')) {
    badgeClass = 'action-failed';
    icon = '❌';
  } else if (actionLower.contains('click') || actionLower.contains('tap')) {
    badgeClass = 'action-click';
    icon = '👆';
  } else if (actionLower.contains('wait')) {
    badgeClass = 'action-wait';
    icon = '⏳';
  } else if (actionLower.contains('scroll')) {
    badgeClass = 'action-scroll';
    icon = '📜';
  } else if (actionLower.contains('input') || actionLower.contains('type')) {
    badgeClass = 'action-input';
    icon = '⌨️';
  } else {
    badgeClass = 'action-other';
    icon = '🔹';
  }

  return '<span class="action-badge $badgeClass">$icon $action</span>';
}

/// Returns feedback badge if present
String getFeedbackBadge(String? feedback) {
  if (feedback == null || feedback.isEmpty) return '';

  final feedbackLower = feedback.toLowerCase();
  String badgeClass;
  String icon;

  if (feedbackLower.contains('passed') || feedbackLower.contains('success')) {
    badgeClass = 'feedback-success';
    icon = '✓';
  } else if (feedbackLower.contains('failed') ||
      feedbackLower.contains('identical')) {
    badgeClass = 'feedback-warning';
    icon = '⚠️';
  } else {
    badgeClass = 'feedback-info';
    icon = 'ℹ️';
  }

  return '<div class="feedback-badge $badgeClass">$icon $feedback</div>';
}

/// Extracts a short task title from the goal text
String extractTaskTitle(String goal) {
  if (goal.isEmpty) return 'Unknown Task';

  // Get the first line (before any newlines)
  final firstLine = goal.split('\n').first.trim();

  // Remove any HTML tags that might have been added
  final cleanLine = firstLine.replaceAll(RegExp(r'<[^>]*>'), '');

  // If too long, truncate
  if (cleanLine.length > 80) {
    return '${cleanLine.substring(0, 77)}...';
  }

  return cleanLine;
}

/// Tries to infer a task ID from the goal content
String inferTaskId(String goal, int taskIndex) {
  // Common patterns in goals that can be used as identifiers
  final goalLower = goal.toLowerCase();

  if (goalLower.contains('home screen')) {
    return 'verify_home_screen';
  } else if (goalLower.contains('pizza recommendation') ||
      goalLower.contains('recommendation on the screen')) {
    return 'request_pizza';
  } else if (goalLower.contains('rate the pizza') ||
      goalLower.contains('love it')) {
    return 'rate_pizza';
  } else if (goalLower.contains('login') || goalLower.contains('sign in')) {
    return 'login';
  }

  return 'task_${taskIndex + 1}';
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
      int taskIndex = 0;

      for (final agentResult in agentResults) {
        final agentGoalRaw = agentResult['goal'] as String? ?? '';
        final agentGoal = agentGoalRaw.replaceAll('\n', '<br>');
        final isGoalAchieved = agentResult['isGoalAchieved'] == true;
        final maxStep = agentResult['maxStep'] ?? 'N/A';
        final deviceName = agentResult['deviceName'] ?? 'Unknown Device';
        final startTimestamp = agentResult['startTimestamp'] as int?;
        final endTimestamp = agentResult['endTimestamp'] as int?;

        final steps = agentResult['steps'] as List? ?? [];

        // Skip empty agent results
        if (agentGoalRaw.isEmpty && steps.isEmpty) continue;

        taskIndex++;
        final taskTitle = extractTaskTitle(agentGoalRaw);
        final taskId = inferTaskId(agentGoalRaw, taskIndex - 1);
        final stepsCount = steps.length;

        // Calculate duration
        String durationStr = '';
        if (startTimestamp != null && endTimestamp != null) {
          final durationMs = endTimestamp - startTimestamp;
          final durationSec = (durationMs / 1000).toStringAsFixed(1);
          durationStr = '${durationSec}s';
        }

        // Add task section header - this is a major visual break
        stepsHtml.add('''
          <div class="task-section ${isGoalAchieved ? 'task-section-success' : 'task-section-failure'}">
            <div class="task-section-header">
              <div class="task-section-title-row">
                <span class="task-number">Task $taskIndex</span>
                <span class="task-id-badge">$taskId</span>
                <span class="task-status-badge ${isGoalAchieved ? 'status-success' : 'status-failure'}">
                  ${isGoalAchieved ? '✅ SUCCESS' : '❌ FAILED'}
                </span>
              </div>
              <h4 class="task-section-title">$taskTitle</h4>
              <div class="task-section-meta">
                <span class="meta-item">📊 $stepsCount steps</span>
                <span class="meta-item">⏱️ $durationStr</span>
                <span class="meta-item">🔄 Max: $maxStep</span>
                <span class="meta-item">📱 $deviceName</span>
              </div>
              <details class="task-goal-details">
                <summary>View Full Goal Description</summary>
                <div class="task-goal-content">$agentGoal</div>
              </details>
            </div>
            <div class="task-section-steps">
        ''');

        int localStepCounter = 0;
        for (final step in steps) {
          localStepCounter++;
          final screenshotPath = getScreenshotPath(
              basePath, step['screenshotFilePath'] as String?);
          if (screenshotPath != null) {
            final summary = step['summary'] as String? ?? '';
            final parsed = parseSummary(summary);
            final stepId = step['stepId'] as String? ?? 'Unknown';
            final timestamp = step['timestamp'] as int?;
            final agentAction = step['agentAction'] as String?;
            final cacheHit = step['cacheHit'] == true;
            final goalFromRequest =
                extractGoalFromAiRequest(step['aiRequest'] as String?);

            // Build the info sections
            final infoSections = <String>[];

            // Step number and time header
            infoSections.add('''
              <div class="step-header">
                <span class="step-number">Step $localStepCounter</span>
                <span class="step-time">${formatTimestamp(timestamp)}</span>
                ${cacheHit ? '<span class="cache-hit">📋 Cached</span>' : ''}
              </div>
            ''');

            // Action badge - most prominent
            if (agentAction != null && agentAction.isNotEmpty) {
              infoSections.add('''
                <div class="action-section">
                  ${getActionBadge(agentAction)}
                </div>
              ''');
            }

            // Feedback section (if present)
            if (parsed['feedback'] != null) {
              infoSections.add(getFeedbackBadge(parsed['feedback']));
            }

            // AI Reasoning section
            if (parsed['memo'] != null && parsed['memo']!.isNotEmpty) {
              infoSections.add('''
                <div class="reasoning-section">
                  <div class="section-label">🧠 AI Reasoning</div>
                  <div class="reasoning-text">${parsed['memo']}</div>
                </div>
              ''');
            }

            // What the AI sees
            if (parsed['imageDescription'] != null &&
                parsed['imageDescription']!.isNotEmpty) {
              infoSections.add('''
                <div class="vision-section">
                  <div class="section-label">👁️ What AI Sees</div>
                  <div class="vision-text">${parsed['imageDescription']}</div>
                </div>
              ''');
            }

            // Assertion result (if present)
            if (parsed['fulfillmentPercent'] != null) {
              final percent = int.tryParse(parsed['fulfillmentPercent']!) ?? 0;
              final progressClass = percent >= 80
                  ? 'progress-success'
                  : (percent >= 50 ? 'progress-warning' : 'progress-danger');
              infoSections.add('''
                <div class="assertion-section">
                  <div class="section-label">📊 Assertion Check</div>
                  <div class="assertion-content">
                    <div class="progress-bar $progressClass" style="--progress: $percent%">
                      <span class="progress-value">${percent}%</span>
                    </div>
                    ${parsed['prompt'] != null ? '<div class="assertion-prompt"><strong>Checking:</strong> ${parsed['prompt']}</div>' : ''}
                    ${parsed['explanation'] != null ? '<div class="assertion-explanation">${parsed['explanation']}</div>' : ''}
                  </div>
                </div>
              ''');
            }

            // Goal from AI request (if available and different from task goal)
            if (goalFromRequest != null) {
              infoSections.add('''
                <div class="goal-section">
                  <div class="section-label">🎯 Step Goal</div>
                  <div class="goal-content">$goalFromRequest</div>
                </div>
              ''');
            }

            // Technical details (collapsed by default conceptually, but shown smaller)
            infoSections.add('''
              <div class="technical-info">
                <details>
                  <summary>Technical Details</summary>
                  <div class="step-id">ID: $stepId</div>
                </details>
              </div>
            ''');

            stepsHtml.add('''
              <div class="screenshot-card">
                <div class="screenshot-image-container">
                  <img src="$screenshotPath" 
                       alt="Test Screenshot" 
                       class="screenshot-image" 
                       onclick="showImage('$screenshotPath')">
                </div>
                <div class="screenshot-info">
                  ${infoSections.join('\n')}
                </div>
              </div>
            ''');
          }
        }

        // Close the task section
        stepsHtml.add('''
            </div>
          </div>
        ''');
      }

      if (stepsHtml.isNotEmpty) {
        historiesHtml.add('''
          <div class="history-section">
            <h3 class="history-title">History $historyIndex / ${histories.length}</h3>
            <div class="steps-container">
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
            :root {
                --bg-primary: #1a1a2e;
                --bg-secondary: #16213e;
                --bg-card: #0f0f23;
                --accent-orange: #ff6b35;
                --accent-purple: #9d4edd;
                --accent-blue: #4ea8de;
                --accent-green: #38b000;
                --accent-red: #ef233c;
                --accent-yellow: #ffd60a;
                --text-primary: #edf2f4;
                --text-secondary: #8d99ae;
                --text-muted: #6c757d;
                --border-color: #2d3a4f;
            }

            * {
                box-sizing: border-box;
            }

            body {
                font-family: 'SF Pro Display', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                margin: 0;
                padding: 20px;
                background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
                color: var(--text-primary);
                min-height: 100vh;
            }

            .container {
                max-width: 1400px;
                margin: 0 auto;
            }

            .overall-summary {
                background: var(--bg-card);
                padding: 24px 32px;
                border-radius: 16px;
                margin-bottom: 24px;
                border: 1px solid var(--border-color);
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            }

            h1 {
                color: var(--accent-orange);
                margin: 0 0 16px 0;
                font-size: 2rem;
                font-weight: 700;
            }

            h2 {
                color: var(--text-primary);
                font-size: 1.5rem;
                margin: 0 0 12px 0;
            }

            .test-stats {
                display: flex;
                gap: 16px;
                flex-wrap: wrap;
            }

            .stat-item {
                padding: 12px 20px;
                border-radius: 10px;
                background: var(--bg-secondary);
                border: 1px solid var(--border-color);
            }

            .stat-label {
                font-weight: 500;
                color: var(--text-secondary);
                margin-right: 8px;
            }

            .stat-value {
                font-weight: 700;
                font-size: 1.2rem;
            }

            .success-text { color: var(--accent-green); }
            .failure-text { color: var(--accent-red); }

            /* Task Section Styles - Major visual breaks between sub-tasks */
            .task-section {
                background: var(--bg-card);
                border-radius: 16px;
                margin: 24px 0;
                overflow: hidden;
                border: 2px solid var(--border-color);
            }

            .task-section-success {
                border-color: var(--accent-green);
            }

            .task-section-failure {
                border-color: var(--accent-red);
            }

            .task-section-header {
                background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-primary) 100%);
                padding: 20px 24px;
                border-bottom: 1px solid var(--border-color);
            }

            .task-section-title-row {
                display: flex;
                align-items: center;
                gap: 12px;
                margin-bottom: 12px;
                flex-wrap: wrap;
            }

            .task-number {
                background: var(--accent-purple);
                color: white;
                font-weight: 800;
                font-size: 0.9rem;
                padding: 6px 14px;
                border-radius: 20px;
            }

            .task-id-badge {
                background: rgba(255, 255, 255, 0.1);
                color: var(--text-secondary);
                font-family: 'SF Mono', monospace;
                font-size: 0.8rem;
                padding: 4px 10px;
                border-radius: 6px;
                border: 1px solid var(--border-color);
            }

            .task-status-badge {
                font-weight: 700;
                font-size: 0.85rem;
                padding: 6px 14px;
                border-radius: 20px;
                margin-left: auto;
            }

            .task-status-badge.status-success {
                background: rgba(56, 176, 0, 0.2);
                color: var(--accent-green);
                border: 1px solid var(--accent-green);
            }

            .task-status-badge.status-failure {
                background: rgba(239, 35, 60, 0.2);
                color: var(--accent-red);
                border: 1px solid var(--accent-red);
            }

            .task-section-title {
                color: var(--text-primary);
                font-size: 1.2rem;
                font-weight: 600;
                margin: 0 0 12px 0;
            }

            .task-section-meta {
                display: flex;
                gap: 16px;
                flex-wrap: wrap;
                margin-bottom: 12px;
            }

            .meta-item {
                color: var(--text-muted);
                font-size: 0.85rem;
            }

            .task-goal-details {
                margin-top: 8px;
            }

            .task-goal-details summary {
                color: var(--accent-blue);
                cursor: pointer;
                font-size: 0.85rem;
                padding: 4px 0;
            }

            .task-goal-details summary:hover {
                color: var(--accent-purple);
            }

            .task-goal-content {
                background: rgba(0, 0, 0, 0.3);
                padding: 16px;
                border-radius: 8px;
                font-size: 0.85rem;
                line-height: 1.6;
                color: var(--text-secondary);
                margin-top: 8px;
                max-height: 300px;
                overflow-y: auto;
            }

            .task-section-steps {
                padding: 20px;
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 16px;
            }

            @media (max-width: 1200px) {
                .task-section-steps {
                    grid-template-columns: 1fr;
                }
            }

            .history-section {
                margin: 24px 0;
            }

            .history-title {
                color: var(--accent-blue);
                font-size: 1.1em;
                margin: 10px 0;
                padding: 10px 16px;
                background: var(--bg-card);
                border-radius: 8px;
                border: 1px solid var(--border-color);
            }

            .steps-container {
                /* Container for all task sections */
            }

            .screenshot-card {
                background: var(--bg-secondary);
                border-radius: 12px;
                border: 1px solid var(--border-color);
                overflow: hidden;
                transition: all 0.3s ease;
                display: flex;
                flex-direction: row;
                align-items: stretch;
            }

            .screenshot-card:hover {
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
                border-color: var(--accent-purple);
            }

            .screenshot-image-container {
                flex: 0 0 auto;
                width: 180px;
                background: var(--bg-card);
                display: flex;
                align-items: center;
                justify-content: center;
                border-right: 1px solid var(--border-color);
                padding: 10px;
            }

            .screenshot-image {
                width: 100%;
                height: auto;
                max-height: 320px;
                object-fit: contain;
                display: block;
                cursor: pointer;
                border-radius: 6px;
                transition: transform 0.2s ease, box-shadow 0.2s ease;
            }

            .screenshot-image:hover {
                transform: scale(1.02);
                box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
            }

            .screenshot-info {
                flex: 1;
                padding: 14px 16px;
                overflow-y: auto;
                max-height: 340px;
            }

            /* Responsive: Stack vertically on smaller screens */
            @media (max-width: 1200px) {
                .screenshot-image-container {
                    width: 160px;
                }

                .screenshot-image {
                    max-height: 280px;
                }
            }

            @media (max-width: 600px) {
                .screenshot-card {
                    flex-direction: column;
                }

                .screenshot-image-container {
                    width: 100%;
                    border-right: none;
                    border-bottom: 1px solid var(--border-color);
                }

                .screenshot-image {
                    max-height: 250px;
                    max-width: 150px;
                }

                .screenshot-info {
                    max-height: none;
                }
            }

            /* Step Header */
            .step-header {
                display: flex;
                align-items: center;
                gap: 12px;
                margin-bottom: 12px;
                flex-wrap: wrap;
            }

            .step-number {
                background: var(--accent-purple);
                color: white;
                font-weight: 700;
                font-size: 0.85rem;
                padding: 4px 12px;
                border-radius: 20px;
            }

            .step-time {
                color: var(--text-muted);
                font-size: 0.85rem;
                font-family: 'SF Mono', monospace;
            }

            .cache-hit {
                font-size: 0.75rem;
                color: var(--accent-blue);
                background: rgba(78, 168, 222, 0.15);
                padding: 2px 8px;
                border-radius: 4px;
            }

            /* Action Badge Styles */
            .action-section {
                margin: 12px 0;
            }

            .action-badge {
                display: inline-block;
                padding: 8px 16px;
                border-radius: 8px;
                font-weight: 600;
                font-size: 0.95rem;
            }

            .action-success {
                background: linear-gradient(135deg, rgba(56, 176, 0, 0.2), rgba(56, 176, 0, 0.1));
                color: var(--accent-green);
                border: 1px solid var(--accent-green);
            }

            .action-failed {
                background: linear-gradient(135deg, rgba(239, 35, 60, 0.2), rgba(239, 35, 60, 0.1));
                color: var(--accent-red);
                border: 1px solid var(--accent-red);
            }

            .action-click {
                background: linear-gradient(135deg, rgba(255, 107, 53, 0.2), rgba(255, 107, 53, 0.1));
                color: var(--accent-orange);
                border: 1px solid var(--accent-orange);
            }

            .action-wait {
                background: linear-gradient(135deg, rgba(255, 214, 10, 0.2), rgba(255, 214, 10, 0.1));
                color: var(--accent-yellow);
                border: 1px solid var(--accent-yellow);
            }

            .action-scroll {
                background: linear-gradient(135deg, rgba(78, 168, 222, 0.2), rgba(78, 168, 222, 0.1));
                color: var(--accent-blue);
                border: 1px solid var(--accent-blue);
            }

            .action-input {
                background: linear-gradient(135deg, rgba(157, 78, 221, 0.2), rgba(157, 78, 221, 0.1));
                color: var(--accent-purple);
                border: 1px solid var(--accent-purple);
            }

            .action-other, .action-unknown {
                background: rgba(141, 153, 174, 0.15);
                color: var(--text-secondary);
                border: 1px solid var(--text-muted);
            }

            /* Feedback Badge */
            .feedback-badge {
                padding: 8px 12px;
                border-radius: 8px;
                font-size: 0.85rem;
                margin: 8px 0;
            }

            .feedback-success {
                background: rgba(56, 176, 0, 0.15);
                color: var(--accent-green);
                border-left: 3px solid var(--accent-green);
            }

            .feedback-warning {
                background: rgba(255, 214, 10, 0.15);
                color: var(--accent-yellow);
                border-left: 3px solid var(--accent-yellow);
            }

            .feedback-info {
                background: rgba(78, 168, 222, 0.15);
                color: var(--accent-blue);
                border-left: 3px solid var(--accent-blue);
            }

            /* Section Styles */
            .reasoning-section, .vision-section, .goal-section, .assertion-section {
                margin: 12px 0;
                padding: 12px;
                border-radius: 8px;
                background: rgba(255, 255, 255, 0.03);
            }

            .section-label {
                font-weight: 600;
                font-size: 0.8rem;
                color: var(--text-secondary);
                margin-bottom: 6px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }

            .reasoning-section {
                border-left: 3px solid var(--accent-purple);
            }

            .reasoning-text {
                color: var(--text-primary);
                font-size: 0.9rem;
                line-height: 1.5;
                font-style: italic;
            }

            .vision-section {
                border-left: 3px solid var(--accent-blue);
            }

            .vision-text {
                color: var(--text-secondary);
                font-size: 0.85rem;
                line-height: 1.4;
            }

            .goal-section {
                border-left: 3px solid var(--accent-orange);
            }

            .goal-content {
                color: var(--text-secondary);
                font-size: 0.85rem;
            }

            /* Assertion / Progress */
            .assertion-section {
                border-left: 3px solid var(--accent-green);
            }

            .progress-bar {
                height: 24px;
                border-radius: 12px;
                background: rgba(255, 255, 255, 0.1);
                position: relative;
                overflow: hidden;
                margin-bottom: 8px;
            }

            .progress-bar::before {
                content: '';
                position: absolute;
                left: 0;
                top: 0;
                height: 100%;
                width: var(--progress);
                border-radius: 12px;
                transition: width 0.3s ease;
            }

            .progress-success::before { background: var(--accent-green); }
            .progress-warning::before { background: var(--accent-yellow); }
            .progress-danger::before { background: var(--accent-red); }

            .progress-value {
                position: absolute;
                right: 12px;
                top: 50%;
                transform: translateY(-50%);
                font-weight: 700;
                font-size: 0.85rem;
                color: var(--text-primary);
            }

            .assertion-prompt {
                font-size: 0.85rem;
                color: var(--text-secondary);
                margin-bottom: 4px;
            }

            .assertion-explanation {
                font-size: 0.85rem;
                color: var(--text-muted);
                font-style: italic;
            }

            /* Technical Info */
            .technical-info {
                margin-top: 12px;
                font-size: 0.75rem;
            }

            .technical-info summary {
                color: var(--text-muted);
                cursor: pointer;
                padding: 4px 0;
            }

            .technical-info summary:hover {
                color: var(--text-secondary);
            }

            .step-id {
                font-family: 'SF Mono', monospace;
                color: var(--text-muted);
                font-size: 0.7rem;
                word-break: break-all;
                padding: 8px;
                background: rgba(0, 0, 0, 0.3);
                border-radius: 4px;
                margin-top: 8px;
            }

            /* Modal */
            .modal {
                display: none;
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background: rgba(0, 0, 0, 0.95);
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
                border-radius: 8px;
            }

            /* Scenario Section */
            .scenario-section {
                margin: 24px 0;
                padding: 24px;
                border-radius: 16px;
                background: var(--bg-card);
                border: 1px solid var(--border-color);
            }

            .scenario-section.success {
                border-left: 4px solid var(--accent-green);
            }

            .scenario-section.failure {
                border-left: 4px solid var(--accent-red);
            }

            .scenario-goal {
                margin: 16px 0;
                padding: 16px;
                background: rgba(255, 255, 255, 0.03);
                border-radius: 8px;
                font-size: 0.9rem;
                line-height: 1.6;
                color: var(--text-secondary);
            }

            .scenario-status {
                font-weight: 700;
                font-size: 1.1rem;
                margin: 12px 0;
            }

            /* Responsive */
            @media (max-width: 768px) {
                .steps-container {
                    grid-template-columns: 1fr;
                }

                .task-header-row {
                    flex-direction: column;
                    align-items: flex-start;
                }
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
