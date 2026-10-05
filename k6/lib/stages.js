// Load profiles - the *shape* of the traffic each test generates.
//
// The shape is what distinguishes one test type from another. The script body
// (what a virtual user actually does) is identical in all three tests.

// Smoke: the smallest possible amount of load. One user, long enough to produce
// a handful of iterations. Answers "does this work at all?".
export const SMOKE = {
  vus: 1,
  duration: "30s",
};

// Load (a.k.a. performance test): ramp up to the traffic we expect in
// production, hold it steady, ramp down. The steady-state plateau is the part
// we measure - the ramps are there so we don't shock the system.
export const LOAD_STAGES = [
  { duration: "30s", target: 10 }, // ramp up
  { duration: "1m", target: 10 }, // steady state <- measure this
  { duration: "30s", target: 0 }, // ramp down
];

// Spike (a.k.a. peak-load test): establish a baseline, jump hard, then drop
// back to the baseline. Going back down is deliberate: we want to see whether
// the system *recovers*, not just how it behaves at the peak.
export const SPIKE_STAGES = [
  { duration: "10s", target: 5 }, // warm up
  { duration: "20s", target: 5 }, // baseline
  { duration: "10s", target: 100 }, // spike
  { duration: "30s", target: 100 }, // hold the peak
  { duration: "10s", target: 5 }, // drop back
  { duration: "20s", target: 5 }, // recovery <- compare with the baseline
  { duration: "10s", target: 0 },
];
