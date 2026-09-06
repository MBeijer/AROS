#define _GNU_SOURCE
#include <elfloader.h>
#include <runtime.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>

void *open_file(struct ELFNode *node, unsigned int *error)
{
    FILE *file = fopen(node->Name, "rb");
    *error = file ? 0 : errno;
    return file;
}

void close_file(void *file) { fclose(file); }
void free_block(void *block) { free(block); }

int read_block(void *file, unsigned long offset, void *dest, unsigned long length)
{
    if (fseek(file, offset, SEEK_SET))
        return errno;
    return fread(dest, 1, length, file) == length ? 0 : EIO;
}

void *load_block(void *file, unsigned long offset, unsigned long length, unsigned int *error)
{
    void *block = malloc(length ? length : 1);
    *error = block ? read_block(file, offset, block, length) : ENOMEM;
    if (*error) {
        free(block);
        return NULL;
    }
    return block;
}

void DisplayError(char *format, ...)
{
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
}

void kprintf(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
}

int main(int argc, char **argv)
{
    struct ELFNode *nodes;
    struct ELF_ModuleInfo *debug = NULL;
    kernel_entry_fun_t entry = NULL;
    unsigned long ro_size, rw_size, bss_size;
    int loaded, i;
    void *ro, *rw;
    char *bss;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <hosted-kernel> [module ...]\n", argv[0]);
        return 2;
    }
    nodes = calloc(argc - 1, sizeof(*nodes));
    if (!nodes) {
        perror("Allocating loader nodes");
        return 1;
    }
    for (i = 0; i < argc - 1; ++i) {
        nodes[i].Name = argv[i + 1];
        nodes[i].Next = i < argc - 2 ? &nodes[i + 1] : NULL;
    }
    if (!GetKernelSize(nodes, &ro_size, &rw_size, &bss_size))
        return 1;

    /* Match the hosted loader's low-address allocation for 32-bit relocations.
       Deliberately omit PROT_EXEC: this test must never enter the kernel. */
    ro = mmap(NULL, ro_size, PROT_READ | PROT_WRITE,
              MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
    rw = mmap(NULL, rw_size + sizeof(void *), PROT_READ | PROT_WRITE,
              MAP_PRIVATE | MAP_ANONYMOUS | MAP_32BIT, -1, 0);
    bss = calloc(1, bss_size ? bss_size : 1);
    if (ro == MAP_FAILED || rw == MAP_FAILED || !bss) {
        perror("Allocating loader test memory");
        return 1;
    }
    loaded = LoadKernel(nodes, ro, rw, bss, (uintptr_t)rw + rw_size,
                        NULL, &entry, &debug);
    if (loaded && entry && debug)
        printf("%d boot module(s) loaded and relocated successfully (entry not executed).\n", argc - 1);
    else
        loaded = 0;
    munmap(ro, ro_size);
    munmap(rw, rw_size + sizeof(void *));
    free(bss);
    free(nodes);
    return loaded ? 0 : 1;
}
