package melody

import "time"

type envelope struct {
	t         int
	msg       []byte
	filter    filterFunc
	writeWait time.Duration // Optional per-message deadline (0 = use Config.WriteWait)
}
