import { NativeModules } from 'react-native';

type CrashVariant = 'runtimeException' | 'nullPointer';

type QuickPizzaCrashModule = {
  crash: (variant: CrashVariant) => void;
};

const crashModule = NativeModules.QuickPizzaCrash as
  | QuickPizzaCrashModule
  | undefined;

export function triggerNativeCrash(variant: CrashVariant): void {
  if (!crashModule?.crash) {
    throw new Error('QuickPizzaCrash native module is not available');
  }

  crashModule.crash(variant);
}
