/*
 * Minimal fallback for One UI 9 builds whose Samsung apps still try to dlopen
 * libpenguin.so even though the source firmware no longer ships the blob.
 *
 * Real target firmware blobs always win in customize.sh; this shared object is
 * only packaged when no source/target libpenguin.so exists.
 */
__attribute__((visibility("default"))) void monsterrom_libpenguin_stub(void)
{
}
