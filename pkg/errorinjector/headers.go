package errorinjector

import (
	"context"
	"net/http"
)

var headerList = []string{
	"x-error-record-recommendation",
	"x-error-record-recommendation-percentage",
	"x-delay-record-recommendation",
	"x-delay-record-recommendation-percentage",
	"x-error-get-ingredients",
	"x-error-get-ingredients-percentage",
	"x-delay-get-ingredients",
	"x-delay-get-ingredients-percentage",
}

func AddErrorHeaders(parentCtx context.Context, request *http.Request) {
	for _, header := range headerList {
		addHeaderFromContext(parentCtx, header, request)
	}
}

func addHeaderFromContext(ctx context.Context, headerName string, request *http.Request) {
	value := ctx.Value(headerName)
	if value != nil {
		request.Header.Add(headerName, value.(string))
	}
}

func InjectErrorHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		for _, header := range headerList {
			ctx = context.WithValue(ctx, header, r.Header.Get(header))
		}
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
