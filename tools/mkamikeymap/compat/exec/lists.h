#ifndef MKAKM_COMPAT_EXEC_LISTS_H
#define MKAKM_COMPAT_EXEC_LISTS_H

#include <exec/types.h>

struct Node {
    struct Node *ln_Succ;
    struct Node *ln_Pred;
    UBYTE ln_Type;
    BYTE ln_Pri;
    char *ln_Name;
};

struct List {
    struct Node *lh_Head;
    struct Node *lh_Tail;
    struct Node *lh_TailPred;
    UBYTE lh_Type;
    UBYTE l_pad;
};

#define NEWLIST(_l)                                     \
do                                                      \
{                                                       \
    struct List *l = (struct List *)(_l);               \
    l->lh_TailPred = (struct Node *)l;                  \
    l->lh_Tail = 0;                                     \
    l->lh_Head = (struct Node *)&l->lh_Tail;            \
} while (0)

#define ADDTAIL(_l,_n)                                    \
do                                                        \
{                                                         \
    struct Node *n = (struct Node *)(_n);                \
    struct List *l = (struct List *)(_l);                \
    n->ln_Succ = (struct Node *)&l->lh_Tail;             \
    n->ln_Pred = l->lh_TailPred;                         \
    l->lh_TailPred->ln_Succ = n;                         \
    l->lh_TailPred = n;                                  \
} while (0)

#define ForeachNode(list, node)                         \
for                                                     \
(                                                       \
    *(void **)&node = (void *)(((struct List *)(list))->lh_Head); \
    ((struct Node *)(node))->ln_Succ;                   \
    *(void **)&node = (void *)(((struct Node *)(node))->ln_Succ)   \
)

#endif
