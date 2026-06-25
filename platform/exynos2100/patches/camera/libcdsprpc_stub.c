/*
 * Exynos-safe fallback for S948B One UI 9 camera/ArcSoft libraries that
 * optionally dlopen Qualcomm's CDSP RPC client. Exynos targets do not have the
 * QTI DSP HAL stack; returning errors lets those libraries stay on CPU paths.
 */
typedef unsigned int uint32_t;
typedef unsigned long uint64_t;
typedef unsigned long size_t;
typedef long remote_handle;
typedef long remote_handle64;

#define DSPRPC_ENOTSUP (-1)

__attribute__((visibility("default"))) void *rpcmem_alloc(int heapid, uint32_t flags, int size)
{
    (void) heapid;
    (void) flags;
    (void) size;
    return (void *) 0;
}

__attribute__((visibility("default"))) void rpcmem_free(void *po)
{
    (void) po;
}

__attribute__((visibility("default"))) int rpcmem_to_fd(void *po)
{
    (void) po;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int remote_handle_open(const char *name, remote_handle *ph)
{
    (void) name;
    if (ph) *ph = 0;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int remote_handle64_open(const char *name, remote_handle64 *ph)
{
    (void) name;
    if (ph) *ph = 0;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int remote_handle_close(remote_handle h)
{
    (void) h;
    return 0;
}

__attribute__((visibility("default"))) int remote_handle64_close(remote_handle64 h)
{
    (void) h;
    return 0;
}

__attribute__((visibility("default"))) int remote_handle_invoke(remote_handle h, uint32_t scalars, void *pra)
{
    (void) h;
    (void) scalars;
    (void) pra;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int remote_handle64_invoke(remote_handle64 h, uint32_t scalars, void *pra)
{
    (void) h;
    (void) scalars;
    (void) pra;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int remote_handle_control(uint32_t req, void *data, uint32_t datalen)
{
    (void) req;
    (void) data;
    (void) datalen;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int remote_handle64_control(remote_handle64 h, uint32_t req, void *data, uint32_t datalen)
{
    (void) h;
    (void) req;
    (void) data;
    (void) datalen;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int fastrpc_mmap(int fd, uint32_t flags, uint64_t vaddrin, int size, uint64_t *vaddrout)
{
    (void) fd;
    (void) flags;
    (void) vaddrin;
    (void) size;
    if (vaddrout) *vaddrout = 0;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int fastrpc_munmap(uint64_t vaddrout, int size)
{
    (void) vaddrout;
    (void) size;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int fastrpc_mem_request(int domain, size_t size, uint64_t *phys, int *fd)
{
    (void) domain;
    (void) size;
    if (phys) *phys = 0;
    if (fd) *fd = -1;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int fastrpc_async_get_status(uint64_t jobid, int timeout, int *status)
{
    (void) jobid;
    (void) timeout;
    if (status) *status = DSPRPC_ENOTSUP;
    return DSPRPC_ENOTSUP;
}

__attribute__((visibility("default"))) int fastrpc_release_async_job(uint64_t jobid)
{
    (void) jobid;
    return DSPRPC_ENOTSUP;
}
