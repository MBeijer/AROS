#define BUFFER_SIZE 1024

extern char *KernelArgs;
extern char *SystemVersion;
extern char buf[BUFFER_SIZE];
extern int VerboseBoot;

int bootstrap(int argc, char ** argv);
