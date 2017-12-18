#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <sys/sem.h>
#include <sys/shm.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <wait.h>
#include <fcntl.h>
#include <sys/msg.h>

struct MSG
{
    long type;
    long long val2[2];
};

int
main(int arg, char **argv)
{
    int n = strtol(argv[2], NULL, 10);
    key_t key = strtol(argv[1], NULL, 10);
    long long x2 = strtoll(argv[3], NULL, 10);
    long long x3 = strtoll(argv[4], NULL, 10);
    long long maxval = strtoll(argv[5], NULL, 10);
    int msid = msgget(key, IPC_CREAT | 0777);
    pid_t *parr = calloc(n, sizeof(*parr));
    for (int i = 0; i < n; ++i) {
        pid_t pid;
        if (!(pid = fork())) {
            while (1) {
                struct MSG s1;
                msgrcv (msid, &s1, sizeof(struct MSG) - sizeof(long), i+1, 0);
                long long tmp = s1.val2[0] + s1.val2[1];
                printf ("%d %lld\n", i, tmp);
                fflush(stdout);
                if (tmp > maxval) {
                    _exit(0);
                }
                s1.val2[0] = s1.val2[1];
                s1.val2[1] = tmp;
                s1.type = (tmp % n) + 1;
                msgsnd(msid, &s1, sizeof(s1) - sizeof(s1.type), 0);
            }
        } else {
            parr[i] = pid;
        }
    }
    for (int i = 0; i < n; ++i) {
        if (parr[i] < 0) {
            for (int j = 0; j < n; ++j) {
                if (parr[j] > 0) {
                    kill(parr[j], SIGTERM);
                }
            }
            msgctl(msid, IPC_RMID, NULL);
            free(parr);
            _exit(1);
        }
    }
    struct MSG s0;
    s0.type = 1;
    s0.val2[0] = x2;
    s0.val2[1] = x3;
    msgsnd(msid, &s0, sizeof(struct MSG) - sizeof(long), 0);
    wait(NULL);
    for (int j = 0; j < n; ++j) {
        kill(parr[j], SIGTERM);
    }
    for (int j = 0; j < n; ++j) {
        wait(NULL);
    }
    msgctl(msid, IPC_RMID, NULL);
    free(parr);
    return 0;
}
