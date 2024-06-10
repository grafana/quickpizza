package errorinjector

import (
	"context"
	"fmt"
	"math/rand"
	"strconv"
	"time"
)

func InjectErrors(ctx context.Context, action string) error {
	errorToInject := ctx.Value(fmt.Sprintf("x-error-%s", action))
	if errorToInject != nil && len(errorToInject.(string)) > 0 {
		errorToInjectPercentage := ctx.Value(fmt.Sprintf("x-error-%s-percentage", action))
		if errorToInjectPercentage != nil && len(errorToInjectPercentage.(string)) > 0 {
			percentage, err := strconv.ParseFloat(errorToInjectPercentage.(string), 64)
			if err != nil {
				// Ignore value
			}
			if rand.Float64() < (percentage / 100.0) {
				return fmt.Errorf("%s", errorToInject)
			}
		} else {
			return fmt.Errorf("%s", errorToInject)
		}
	}

	delayToInject := ctx.Value(fmt.Sprintf("x-delay-%s", action))
	if delayToInject != nil && len(delayToInject.(string)) > 0 {
		duration, err := time.ParseDuration(delayToInject.(string))
		if err != nil {
			// Ignore value
		}
		delayToInjectPercentage := ctx.Value(fmt.Sprintf("x-delay-%s-percentage", action))
		if delayToInjectPercentage != nil && len(delayToInjectPercentage.(string)) > 0 {
			percentage, err := strconv.ParseFloat(delayToInjectPercentage.(string), 64)
			if err != nil {
				// Ignore value
			}
			if rand.Float64() < (percentage / 100.0) {
				time.Sleep(duration)
			}
		} else {
			time.Sleep(duration)
		}
	}
	return nil
}
