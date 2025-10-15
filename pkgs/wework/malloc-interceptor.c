#define _GNU_SOURCE
#include <curl/curl.h>
#include <curl/options.h>
#include <dlfcn.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#undef curl_easy_setopt

typedef CURLcode (*curl_easy_setopt_fn)(CURL *handle, CURLoption option, ...);
typedef const struct curl_easyoption *(*curl_easy_option_by_id_fn)(CURLoption option);

static curl_easy_setopt_fn real_curl_easy_setopt = NULL;
static curl_easy_option_by_id_fn real_curl_easy_option_by_id = NULL;

__attribute__((constructor)) static void curl_guard_init(void) {
    fprintf(stderr, "curl-guard: interceptor loaded\n");
}

static void ensure_real_symbols(void) {
    if (!real_curl_easy_setopt) {
        real_curl_easy_setopt = (curl_easy_setopt_fn)dlsym(RTLD_NEXT, "curl_easy_setopt");
    }
    if (!real_curl_easy_option_by_id) {
        real_curl_easy_option_by_id =
            (curl_easy_option_by_id_fn)dlsym(RTLD_NEXT, "curl_easy_option_by_id");
    }
}

static const struct curl_easyoption *option_info(CURLoption option) {
    if (!real_curl_easy_option_by_id) {
        return NULL;
    }
    return real_curl_easy_option_by_id(option);
}

static bool should_duplicate_string(const struct curl_easyoption *info) {
    if (!info) {
        return false;
    }
    return info->type == CURLOT_STRING;
}

CURLcode curl_easy_setopt(CURL *handle, CURLoption option, ...) {
    ensure_real_symbols();
    if (!real_curl_easy_setopt) {
        fprintf(stderr, "curl-guard: failed to locate real curl_easy_setopt\n");
        return CURLE_FAILED_INIT;
    }

    const struct curl_easyoption *info = option_info(option);

    va_list ap;
    va_start(ap, option);

    CURLcode result = CURLE_OK;

    if (!info) {
        /* Fallback: assume pointer argument */
        void *value = va_arg(ap, void *);
        fprintf(stderr, "curl-guard: option %d (unknown) raw pointer=%p\n", option, value);
        result = real_curl_easy_setopt(handle, option, value);
        va_end(ap);
        return result;
    }

    switch (info->type) {
        case CURLOT_LONG:
        case CURLOT_VALUES: {
            long value = va_arg(ap, long);
            fprintf(stderr, "curl-guard: %s (long) value=%ld\n",
                    info->name ? info->name : "<unknown>", value);
            result = real_curl_easy_setopt(handle, option, value);
            break;
        }
        case CURLOT_OFF_T: {
            curl_off_t value = va_arg(ap, curl_off_t);
            fprintf(stderr, "curl-guard: %s (off_t) value=%lld\n",
                    info->name ? info->name : "<unknown>", (long long)value);
            result = real_curl_easy_setopt(handle, option, value);
            break;
        }
        case CURLOT_STRING: {
            const char *value = va_arg(ap, const char *);
            char *dup = value ? strdup(value) : NULL;
            if (value && !dup) {
                fprintf(stderr, "curl-guard: strdup failed for option %s\n",
                        info->name ? info->name : "<unknown>");
                result = CURLE_OUT_OF_MEMORY;
                break;
            }
            fprintf(stderr, "curl-guard: %s (string) original=%p dup=%p value=\"%s\"\n",
                    info->name ? info->name : "<unknown>", (const void *)value, (void *)dup,
                    value ? value : "(null)");
            result = real_curl_easy_setopt(handle, option, dup);
            if (result != CURLE_OK && dup) {
                free(dup);
            }
            break;
        }
        case CURLOT_OBJECT:
        case CURLOT_CBPTR:
        case CURLOT_SLIST:
        case CURLOT_BLOB:
        case CURLOT_FUNCTION:
        default: {
            void *value = va_arg(ap, void *);
            fprintf(stderr, "curl-guard: %s (ptr type=%d) value=%p\n",
                    info->name ? info->name : "<unknown>", info->type, value);
            result = real_curl_easy_setopt(handle, option, value);
            break;
        }
    }

    va_end(ap);
    return result;
}
