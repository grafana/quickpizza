#!/usr/bin/env node
/**
 * Generates HTML report from Arbigent E2E test results.
 * Reads result.yml and screenshots from the given path, outputs visual_report.html.
 *
 * Usage: node generate_report.js --path=/path/to/arbigent-result
 */

const fs = require('fs');
const path = require('path');
const { parse: parseYaml } = require('yaml');

function formatTimestamp(timestampMs) {
  if (timestampMs == null || timestampMs === 0) return 'Unknown time';
  try {
    const dt = new Date(timestampMs);
    return dt.toISOString().replace('T', ' ').slice(0, 19);
  } catch (e) {
    return 'Unknown time';
  }
}

function extractGoalFromAiRequest(aiRequest) {
  if (!aiRequest || !aiRequest.includes('Goal:')) return null;
  try {
    const goalStart = aiRequest.indexOf('Goal:') + 5;
    const goalEnd = aiRequest.indexOf('\n\n', goalStart);
    const goal =
      goalEnd === -1
        ? aiRequest.slice(goalStart).trim()
        : aiRequest.slice(goalStart, goalEnd).trim();
    return goal.replace(/\n/g, '<br>');
  } catch (e) {
    return null;
  }
}

function getScreenshotPath(basePath, screenshotName) {
  if (!screenshotName) return null;
  const fileName = path.basename(screenshotName);
  const nameWithoutExt = path.basename(fileName, path.extname(fileName));
  const annotatedName = `${nameWithoutExt}_annotated.png`;
  const annotatedPath = path.join(basePath, 'screenshots', annotatedName);
  const regularPath = path.join(basePath, 'screenshots', fileName);
  if (fs.existsSync(annotatedPath)) return `screenshots/${annotatedName}`;
  if (fs.existsSync(regularPath)) return `screenshots/${fileName}`;
  return null;
}

function parseSummary(summary) {
  const result = {
    imageDescription: null,
    memo: null,
    actionDone: null,
    feedback: null,
    fulfillmentPercent: null,
    prompt: null,
    explanation: null,
  };
  if (!summary) return result;
  const lines = summary.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('image description:'))
      result.imageDescription = trimmed.slice('image description:'.length).trim();
    else if (trimmed.startsWith('memo:'))
      result.memo = trimmed.slice('memo:'.length).trim();
    else if (trimmed.startsWith('action done:'))
      result.actionDone = trimmed.slice('action done:'.length).trim();
    else if (trimmed.startsWith('feedback:'))
      result.feedback = trimmed.slice('feedback:'.length).trim();
    else if (trimmed.startsWith('fulfillmentPercent:'))
      result.fulfillmentPercent = trimmed
        .slice('fulfillmentPercent:'.length)
        .trim();
    else if (trimmed.startsWith('prompt:'))
      result.prompt = trimmed.slice('prompt:'.length).trim();
    else if (trimmed.startsWith('explanation:'))
      result.explanation = trimmed.slice('explanation:'.length).trim();
  }
  return result;
}

function getActionBadge(action) {
  if (!action || !action.length)
    return '<span class="action-badge action-unknown">No Action</span>';
  const actionLower = action.toLowerCase();
  let badgeClass, icon;
  if (actionLower.includes('goal achieved')) {
    badgeClass = 'action-success';
    icon = '✅';
  } else if (actionLower.includes('failed')) {
    badgeClass = 'action-failed';
    icon = '❌';
  } else if (actionLower.includes('click') || actionLower.includes('tap')) {
    badgeClass = 'action-click';
    icon = '👆';
  } else if (actionLower.includes('wait')) {
    badgeClass = 'action-wait';
    icon = '⏳';
  } else if (actionLower.includes('scroll')) {
    badgeClass = 'action-scroll';
    icon = '📜';
  } else if (actionLower.includes('input') || actionLower.includes('type')) {
    badgeClass = 'action-input';
    icon = '⌨️';
  } else {
    badgeClass = 'action-other';
    icon = '🔹';
  }
  return `<span class="action-badge ${badgeClass}">${icon} ${escapeHtml(action)}</span>`;
}

function getFeedbackBadge(feedback) {
  if (!feedback || !feedback.length) return '';
  const feedbackLower = feedback.toLowerCase();
  let badgeClass, icon;
  if (feedbackLower.includes('passed') || feedbackLower.includes('success')) {
    badgeClass = 'feedback-success';
    icon = '✓';
  } else if (
    feedbackLower.includes('failed') ||
    feedbackLower.includes('identical')
  ) {
    badgeClass = 'feedback-warning';
    icon = '⚠️';
  } else {
    badgeClass = 'feedback-info';
    icon = 'ℹ️';
  }
  return `<div class="feedback-badge ${badgeClass}">${icon} ${escapeHtml(feedback)}</div>`;
}

function escapeHtml(str) {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function extractTaskTitle(goal) {
  if (!goal) return 'Unknown Task';
  const firstLine = goal.split('\n')[0].trim();
  const cleanLine = firstLine.replace(/<[^>]*>/g, '');
  if (cleanLine.length > 80) return cleanLine.slice(0, 77) + '...';
  return cleanLine;
}

function inferTaskId(goal, taskIndex) {
  if (!goal) return `task_${taskIndex + 1}`;
  const goalLower = goal.toLowerCase();
  if (goalLower.includes('home screen')) return 'verify_home_screen';
  if (
    goalLower.includes('pizza recommendation') ||
    goalLower.includes('recommendation on the screen')
  )
    return 'request_pizza';
  if (goalLower.includes('rate the pizza') || goalLower.includes('love it'))
    return 'rate_pizza';
  if (goalLower.includes('login') || goalLower.includes('sign in'))
    return 'login';
  return `task_${taskIndex + 1}`;
}

function getStyles() {
  return `
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
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      margin: 0; padding: 20px;
      background: linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-secondary) 100%);
      color: var(--text-primary);
      min-height: 100vh;
    }
    .container { max-width: 1400px; margin: 0 auto; }
    .overall-summary {
      background: var(--bg-card);
      padding: 24px 32px;
      border-radius: 16px;
      margin-bottom: 24px;
      border: 1px solid var(--border-color);
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
    }
    h1 { color: var(--accent-orange); margin: 0 0 16px 0; font-size: 2rem; font-weight: 700; }
    h2 { color: var(--text-primary); font-size: 1.5rem; margin: 0 0 12px 0; }
    .test-stats { display: flex; gap: 16px; flex-wrap: wrap; }
    .stat-item {
      padding: 12px 20px;
      border-radius: 10px;
      background: var(--bg-secondary);
      border: 1px solid var(--border-color);
    }
    .stat-label { font-weight: 500; color: var(--text-secondary); margin-right: 8px; }
    .stat-value { font-weight: 700; font-size: 1.2rem; }
    .success-text { color: var(--accent-green); }
    .failure-text { color: var(--accent-red); }
    .task-section {
      background: var(--bg-card);
      border-radius: 16px;
      margin: 24px 0;
      overflow: hidden;
      border: 2px solid var(--border-color);
    }
    .task-section-success { border-color: var(--accent-green); }
    .task-section-failure { border-color: var(--accent-red); }
    .task-section-header {
      background: linear-gradient(135deg, var(--bg-secondary) 0%, var(--bg-primary) 100%);
      padding: 20px 24px;
      border-bottom: 1px solid var(--border-color);
    }
    .task-section-title-row { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; flex-wrap: wrap; }
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
      font-family: monospace;
      font-size: 0.8rem;
      padding: 4px 10px;
      border-radius: 6px;
      border: 1px solid var(--border-color);
    }
    .task-status-badge { font-weight: 700; font-size: 0.85rem; padding: 6px 14px; border-radius: 20px; margin-left: auto; }
    .task-status-badge.status-success { background: rgba(56, 176, 0, 0.2); color: var(--accent-green); border: 1px solid var(--accent-green); }
    .task-status-badge.status-failure { background: rgba(239, 35, 60, 0.2); color: var(--accent-red); border: 1px solid var(--accent-red); }
    .task-section-title { color: var(--text-primary); font-size: 1.2rem; font-weight: 600; margin: 0 0 12px 0; }
    .task-section-meta { display: flex; gap: 16px; flex-wrap: wrap; margin-bottom: 12px; }
    .meta-item { color: var(--text-muted); font-size: 0.85rem; }
    .task-goal-details { margin-top: 8px; }
    .task-goal-details summary { color: var(--accent-blue); cursor: pointer; font-size: 0.85rem; padding: 4px 0; }
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
    .task-section-steps { padding: 20px; display: grid; grid-template-columns: repeat(2, 1fr); gap: 16px; }
    @media (max-width: 1200px) { .task-section-steps { grid-template-columns: 1fr; } }
    .history-section { margin: 24px 0; }
    .history-title {
      color: var(--accent-blue);
      font-size: 1.1em;
      margin: 10px 0;
      padding: 10px 16px;
      background: var(--bg-card);
      border-radius: 8px;
      border: 1px solid var(--border-color);
    }
    .screenshot-card {
      background: var(--bg-secondary);
      border-radius: 12px;
      border: 1px solid var(--border-color);
      overflow: hidden;
      display: flex;
      flex-direction: row;
      align-items: stretch;
    }
    .screenshot-card:hover { box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4); border-color: var(--accent-purple); }
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
    }
    .screenshot-info { flex: 1; padding: 14px 16px; overflow-y: auto; max-height: 340px; }
    @media (max-width: 600px) {
      .screenshot-card { flex-direction: column; }
      .screenshot-image-container { width: 100%; border-right: none; border-bottom: 1px solid var(--border-color); }
    }
    .step-header { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; flex-wrap: wrap; }
    .step-number { background: var(--accent-purple); color: white; font-weight: 700; font-size: 0.85rem; padding: 4px 12px; border-radius: 20px; }
    .step-time { color: var(--text-muted); font-size: 0.85rem; font-family: monospace; }
    .cache-hit { font-size: 0.75rem; color: var(--accent-blue); background: rgba(78, 168, 222, 0.15); padding: 2px 8px; border-radius: 4px; }
    .action-section { margin: 12px 0; }
    .action-badge { display: inline-block; padding: 8px 16px; border-radius: 8px; font-weight: 600; font-size: 0.95rem; }
    .action-success { background: linear-gradient(135deg, rgba(56, 176, 0, 0.2), rgba(56, 176, 0, 0.1)); color: var(--accent-green); border: 1px solid var(--accent-green); }
    .action-failed { background: linear-gradient(135deg, rgba(239, 35, 60, 0.2), rgba(239, 35, 60, 0.1)); color: var(--accent-red); border: 1px solid var(--accent-red); }
    .action-click { background: linear-gradient(135deg, rgba(255, 107, 53, 0.2), rgba(255, 107, 53, 0.1)); color: var(--accent-orange); border: 1px solid var(--accent-orange); }
    .action-wait { background: linear-gradient(135deg, rgba(255, 214, 10, 0.2), rgba(255, 214, 10, 0.1)); color: var(--accent-yellow); border: 1px solid var(--accent-yellow); }
    .action-scroll { background: linear-gradient(135deg, rgba(78, 168, 222, 0.2), rgba(78, 168, 222, 0.1)); color: var(--accent-blue); border: 1px solid var(--accent-blue); }
    .action-input { background: linear-gradient(135deg, rgba(157, 78, 221, 0.2), rgba(157, 78, 221, 0.1)); color: var(--accent-purple); border: 1px solid var(--accent-purple); }
    .action-other, .action-unknown { background: rgba(141, 153, 174, 0.15); color: var(--text-secondary); border: 1px solid var(--text-muted); }
    .feedback-badge { padding: 8px 12px; border-radius: 8px; font-size: 0.85rem; margin: 8px 0; }
    .feedback-success { background: rgba(56, 176, 0, 0.15); color: var(--accent-green); border-left: 3px solid var(--accent-green); }
    .feedback-warning { background: rgba(255, 214, 10, 0.15); color: var(--accent-yellow); border-left: 3px solid var(--accent-yellow); }
    .feedback-info { background: rgba(78, 168, 222, 0.15); color: var(--accent-blue); border-left: 3px solid var(--accent-blue); }
    .reasoning-section, .vision-section, .goal-section, .assertion-section { margin: 12px 0; padding: 12px; border-radius: 8px; background: rgba(255, 255, 255, 0.03); }
    .section-label { font-weight: 600; font-size: 0.8rem; color: var(--text-secondary); margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.5px; }
    .reasoning-section { border-left: 3px solid var(--accent-purple); }
    .reasoning-text { color: var(--text-primary); font-size: 0.9rem; line-height: 1.5; font-style: italic; }
    .vision-section { border-left: 3px solid var(--accent-blue); }
    .vision-text { color: var(--text-secondary); font-size: 0.85rem; line-height: 1.4; }
    .goal-section { border-left: 3px solid var(--accent-orange); }
    .goal-content { color: var(--text-secondary); font-size: 0.85rem; }
    .assertion-section { border-left: 3px solid var(--accent-green); }
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
      left: 0; top: 0;
      height: 100%;
      width: var(--progress);
      border-radius: 12px;
    }
    .progress-success::before { background: var(--accent-green); }
    .progress-warning::before { background: var(--accent-yellow); }
    .progress-danger::before { background: var(--accent-red); }
    .progress-value { position: absolute; right: 12px; top: 50%; transform: translateY(-50%); font-weight: 700; font-size: 0.85rem; color: var(--text-primary); }
    .assertion-prompt { font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 4px; }
    .assertion-explanation { font-size: 0.85rem; color: var(--text-muted); font-style: italic; }
    .technical-info { margin-top: 12px; font-size: 0.75rem; }
    .technical-info summary { color: var(--text-muted); cursor: pointer; padding: 4px 0; }
    .step-id { font-family: monospace; color: var(--text-muted); font-size: 0.7rem; word-break: break-all; padding: 8px; background: rgba(0, 0, 0, 0.3); border-radius: 4px; margin-top: 8px; }
    .modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0, 0, 0, 0.95); z-index: 1000; justify-content: center; align-items: center; }
    .modal.active { display: flex; }
    .modal img { max-width: 90%; max-height: 90vh; object-fit: contain; border-radius: 8px; }
    .scenario-section { margin: 24px 0; padding: 24px; border-radius: 16px; background: var(--bg-card); border: 1px solid var(--border-color); }
    .scenario-section.success { border-left: 4px solid var(--accent-green); }
    .scenario-section.failure { border-left: 4px solid var(--accent-red); }
    .scenario-goal { margin: 16px 0; padding: 16px; background: rgba(255, 255, 255, 0.03); border-radius: 8px; font-size: 0.9rem; line-height: 1.6; color: var(--text-secondary); }
    .scenario-status { font-weight: 700; font-size: 1.1rem; margin: 12px 0; }
  `;
}

function generateHtml(data, basePath) {
  const scenarios = data.scenarios || [];
  const totalScenarios = scenarios.length;
  const successfulScenarios = scenarios.filter((s) => s.isSuccess === true)
    .length;

  const overallSummary = `
    <div class="overall-summary">
      <h1>🍕 QuickPizza E2E Test Results</h1>
      <div class="test-stats">
        <div class="stat-item">
          <span class="stat-label">Total Scenarios:</span>
          <span class="stat-value">${totalScenarios}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Successful:</span>
          <span class="stat-value success-text">${successfulScenarios}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Failed:</span>
          <span class="stat-value failure-text">${totalScenarios - successfulScenarios}</span>
        </div>
      </div>
    </div>
  `;

  const scenariosHtml = scenarios
    .map((scenario) => {
      const scenarioId = scenario.id || 'Unknown Scenario';
      const scenarioGoal = (scenario.goal || '').replace(/\n/g, '<br>');
      const isSuccess = scenario.isSuccess === true;
      const scenarioClass = isSuccess ? 'success' : 'failure';
      const histories = scenario.histories || [];
      const historiesHtml = [];

      for (let i = 0; i < histories.length; i++) {
        const history = histories[i];
        const historyIndex = i + 1;
        const stepsHtml = [];
        const agentResults = history.agentResults || [];
        let taskIndex = 0;

        for (const agentResult of agentResults) {
          const agentGoalRaw = agentResult.goal || '';
          const agentGoal = agentGoalRaw.replace(/\n/g, '<br>');
          const isGoalAchieved = agentResult.isGoalAchieved === true;
          const maxStep = agentResult.maxStep ?? 'N/A';
          const deviceName = agentResult.deviceName || 'Unknown Device';
          const startTimestamp = agentResult.startTimestamp;
          const endTimestamp = agentResult.endTimestamp;
          const steps = agentResult.steps || [];

          if (!agentGoalRaw && steps.length === 0) continue;

          taskIndex++;
          const taskTitle = extractTaskTitle(agentGoalRaw);
          const taskId = inferTaskId(agentGoalRaw, taskIndex - 1);
          const stepsCount = steps.length;

          let durationStr = '';
          if (startTimestamp != null && endTimestamp != null) {
            durationStr = `${((endTimestamp - startTimestamp) / 1000).toFixed(1)}s`;
          }

          stepsHtml.push(`
          <div class="task-section ${isGoalAchieved ? 'task-section-success' : 'task-section-failure'}">
            <div class="task-section-header">
              <div class="task-section-title-row">
                <span class="task-number">Task ${taskIndex}</span>
                <span class="task-id-badge">${taskId}</span>
                <span class="task-status-badge ${isGoalAchieved ? 'status-success' : 'status-failure'}">
                  ${isGoalAchieved ? '✅ SUCCESS' : '❌ FAILED'}
                </span>
              </div>
              <h4 class="task-section-title">${escapeHtml(taskTitle)}</h4>
              <div class="task-section-meta">
                <span class="meta-item">📊 ${stepsCount} steps</span>
                <span class="meta-item">⏱️ ${durationStr}</span>
                <span class="meta-item">🔄 Max: ${maxStep}</span>
                <span class="meta-item">📱 ${escapeHtml(deviceName)}</span>
              </div>
              <details class="task-goal-details">
                <summary>View Full Goal Description</summary>
                <div class="task-goal-content">${agentGoal}</div>
              </details>
            </div>
            <div class="task-section-steps">
          `);

          let localStepCounter = 0;
          for (const step of steps) {
            localStepCounter++;
            const screenshotPath = getScreenshotPath(
              basePath,
              step.screenshotFilePath
            );
            if (screenshotPath) {
              const parsed = parseSummary(step.summary);
              const stepId = step.stepId || 'Unknown';
              const timestamp = step.timestamp;
              const agentAction = step.agentAction;
              const cacheHit = step.cacheHit === true;
              const goalFromRequest = extractGoalFromAiRequest(step.aiRequest);

              const infoSections = [];

              infoSections.push(`
                <div class="step-header">
                  <span class="step-number">Step ${localStepCounter}</span>
                  <span class="step-time">${formatTimestamp(timestamp)}</span>
                  ${cacheHit ? '<span class="cache-hit">📋 Cached</span>' : ''}
                </div>
              `);

              if (agentAction) {
                infoSections.push(`
                  <div class="action-section">
                    ${getActionBadge(agentAction)}
                  </div>
                `);
              }

              if (parsed.feedback) {
                infoSections.push(getFeedbackBadge(parsed.feedback));
              }

              if (parsed.imageDescription) {
                infoSections.push(`
                  <div class="vision-section">
                    <div class="section-label">👁️ What AI Sees</div>
                    <div class="vision-text">${escapeHtml(parsed.imageDescription)}</div>
                  </div>
                `);
              }

              if (parsed.memo) {
                infoSections.push(`
                  <div class="reasoning-section">
                    <div class="section-label">🧠 AI Reasoning</div>
                    <div class="reasoning-text">${escapeHtml(parsed.memo)}</div>
                  </div>
                `);
              }

              if (parsed.fulfillmentPercent) {
                const percent =
                  parseInt(parsed.fulfillmentPercent, 10) || 0;
                const progressClass =
                  percent >= 80
                    ? 'progress-success'
                    : percent >= 50
                      ? 'progress-warning'
                      : 'progress-danger';
                infoSections.push(`
                  <div class="assertion-section">
                    <div class="section-label">📊 Assertion Check</div>
                    <div class="assertion-content">
                      <div class="progress-bar ${progressClass}" style="--progress: ${percent}%">
                        <span class="progress-value">${percent}%</span>
                      </div>
                      ${parsed.prompt ? `<div class="assertion-prompt"><strong>Checking:</strong> ${escapeHtml(parsed.prompt)}</div>` : ''}
                      ${parsed.explanation ? `<div class="assertion-explanation">${escapeHtml(parsed.explanation)}</div>` : ''}
                    </div>
                  </div>
                `);
              }

              if (goalFromRequest) {
                infoSections.push(`
                  <div class="goal-section">
                    <div class="section-label">🎯 Step Goal</div>
                    <div class="goal-content">${goalFromRequest}</div>
                  </div>
                `);
              }

              infoSections.push(`
                <div class="technical-info">
                  <details>
                    <summary>Technical Details</summary>
                    <div class="step-id">ID: ${escapeHtml(stepId)}</div>
                  </details>
                </div>
              `);

              stepsHtml.push(`
              <div class="screenshot-card">
                <div class="screenshot-image-container">
                  <img src="${screenshotPath}" alt="Test Screenshot" class="screenshot-image" onclick="showImage('${screenshotPath.replace(/'/g, "\\'")}')">
                </div>
                <div class="screenshot-info">
                  ${infoSections.join('\n')}
                </div>
              </div>
            `);
            }
          }

          stepsHtml.push(`
            </div>
          </div>
          `);
        }

        if (stepsHtml.length > 0) {
          historiesHtml.push(`
          <div class="history-section">
            <h3 class="history-title">History ${historyIndex} / ${histories.length}</h3>
            <div class="steps-container">
              ${stepsHtml.join('\n')}
            </div>
          </div>
        `);
        }
      }

      return `
      <div class="scenario-section ${scenarioClass}">
        <h2>Scenario: ${escapeHtml(scenarioId)}</h2>
        <div class="scenario-goal">${scenarioGoal}</div>
        <div class="scenario-status">Status: ${isSuccess ? '✅ Success' : '❌ Failure'}</div>
        ${historiesHtml.join('\n')}
      </div>
    `;
    })
    .join('\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>QuickPizza E2E Test Results</title>
  <style>${getStyles()}</style>
</head>
<body>
  <div class="container">
    ${overallSummary}
    <div class="scenarios">
      ${scenariosHtml}
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
</html>`;
}

function main() {
  const args = process.argv.slice(2);
  let basePath = null;
  for (const arg of args) {
    if (arg.startsWith('--path=')) {
      basePath = arg.slice(7);
      break;
    }
    if (arg === '--path' || arg === '-p') {
      const idx = args.indexOf(arg);
      basePath = args[idx + 1];
      break;
    }
  }

  if (!basePath) {
    console.error('Error: --path is required');
    console.error('Usage: node generate_report.js --path=/path/to/arbigent-result');
    process.exit(1);
  }

  if (!fs.existsSync(basePath)) {
    console.error(`Error: Directory does not exist: ${basePath}`);
    process.exit(1);
  }

  const resultPath = path.join(basePath, 'result.yml');
  if (!fs.existsSync(resultPath)) {
    console.error(`Error: result.yml not found in: ${basePath}`);
    process.exit(1);
  }

  const screenshotsPath = path.join(basePath, 'screenshots');
  if (!fs.existsSync(screenshotsPath)) {
    console.error(`Error: screenshots directory not found in: ${basePath}`);
    process.exit(1);
  }

  const content = fs.readFileSync(resultPath, 'utf8');
  const data = parseYaml(content);

  const html = generateHtml(data, basePath);
  const outputPath = path.join(basePath, 'visual_report.html');
  fs.writeFileSync(outputPath, html);

  console.log(`Report generated successfully at: ${outputPath}`);
}

main();
