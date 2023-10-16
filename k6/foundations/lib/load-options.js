
export const AverageStages = [
  { duration: "5s", target: 3 },
  { duration: "10s", target: 3 },
  { duration: "5s", target: 0 },
];

export const StressStages = [
  { duration: "5s", target: 5 },
  { duration: "10s", target: 5 },
  { duration: "5s", target: 0 },
];

export const SpikeStages = [
  { duration: "30s", target: 100 },
  { duration: "2m", target: 100 },
  { duration: "30s", target: 50 },
  { duration: "2m", target: 50 },
  { duration: "10s", target: 0 },
];

export const SoakStages = [
  { duration: "10m", target: 5 },
  { duration: "1h", target: 5 },
  { duration: "5m", target: 0 },
];

export const SmokeOptions = {
  vus: "1",
  duration: "10s",
};
