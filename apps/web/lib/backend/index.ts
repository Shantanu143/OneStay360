// The backend the app runs on. Demo mode keeps a full sample workspace in the
// browser; see README for connecting the live Firebase project.
import type { Backend } from "./api";
import { DemoBackend } from "./demo";

let instance: Backend | null = null;

export function getBackend(): Backend {
  if (!instance) instance = new DemoBackend();
  return instance;
}

export { BackendError } from "./api";
export type { Backend } from "./api";
