#define _GNU_SOURCE

#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static void (*real_free)(void *) = NULL;
static void (*real_operator_delete)(void *) = NULL;
static void (*real_operator_delete_size)(void *, size_t) = NULL;
static pthread_once_t init_once = PTHREAD_ONCE_INIT;

static void resolve_symbols(void) {
    real_free = (void (*)(void *))dlsym(RTLD_NEXT, "free");
    real_operator_delete =
        (void (*)(void *))dlsym(RTLD_NEXT, "_ZdlPv");              // operator delete(void*)
    real_operator_delete_size =
        (void (*)(void *, size_t))dlsym(RTLD_NEXT, "_ZdlPvm");      // operator delete(void*, size_t)
}

static int should_ignore_pointer(const void *ptr) {
    if (!ptr) {
        return 0;
    }

    uintptr_t addr = (uintptr_t)ptr;

    /* Observed problematic frees target addresses in a high, anonymous region
       around 0x38e0_0000_0000 that never belongs to the allocator. */
    const uintptr_t suspicious_base = 0x38e000000000ULL;
    const uintptr_t suspicious_end = 0x38f000000000ULL;

    if (addr >= suspicious_base && addr < suspicious_end) {
        fprintf(stderr, "free-guard: ignoring suspicious pointer %p\n", ptr);
        return 1;
    }

    return 0;
}

void free(void *ptr) {
    pthread_once(&init_once, resolve_symbols);

    if (!ptr) {
        return;
    }

    if (should_ignore_pointer(ptr)) {
        return;
    }

    real_free(ptr);
}

void _ZdlPv(void *ptr) {
    pthread_once(&init_once, resolve_symbols);

    if (!ptr) {
        return;
    }

    if (should_ignore_pointer(ptr)) {
        return;
    }

    if (real_operator_delete) {
        real_operator_delete(ptr);
    } else {
        real_free(ptr);
    }
}

void _ZdlPvm(void *ptr, size_t size) {
    (void)size;
    pthread_once(&init_once, resolve_symbols);

    if (!ptr) {
        return;
    }

    if (should_ignore_pointer(ptr)) {
        return;
    }

    if (real_operator_delete_size) {
        real_operator_delete_size(ptr, size);
    } else if (real_operator_delete) {
        real_operator_delete(ptr);
    } else {
        real_free(ptr);
    }
}
