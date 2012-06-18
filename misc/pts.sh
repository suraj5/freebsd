#!/bin/sh

#
# Copyright (c) 2012 Peter Holm <pho@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD$
#

# Page fault in ttydev_open+0x2d seen. Fixed in r237219.

[ `id -u ` -ne 0 ] && echo "Must be root!" && exit 1

here=`pwd`
cd /tmp
sed '1,/^EOF/d' < $here/$0 > pts.c
cc -o pts -Wall -Wextra -O2 pts.c -lutil
rm -f pts.c

/tmp/pts &

while kill -0 $! 2>/dev/null; do
	$here/../testcases/swap/swap -t 2m -i 20
done
wait

rm -f /tmp/pts
exit 0
EOF
#include <sys/types.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <fts.h>
#include <libutil.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/param.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

void
churn(char *path)
{

	FTS *fts;
	FTSENT *p;
	int fd, ftsoptions, i;
	char *args[2];

	ftsoptions = 0;
	args[0] = path;
	args[1] = 0;

	setproctitle("churn");
	for (i = 0; i < 5000; i++) {
		if ((fts = fts_open(args, ftsoptions, NULL)) == NULL)
			err(1, "fts_open");

		while ((p = fts_read(fts)) != NULL) {
			if (p->fts_info == FTS_D ||
			   p->fts_info == FTS_DP)
				continue;
			if ((fd = open(p->fts_path, O_RDONLY)) > 0)
				close(fd);

		}

		if (errno != 0 && errno != ENOENT)
			err(1, "fts_read");
		if (fts_close(fts) == -1)
			err(1, "fts_close()");
	}

	_exit(0);
}

void
pty(void)
{
        int i, master, slave;
	char slname[1025];

	setproctitle("pty");
	for (i = 0; i < 20000; i++) {
		if (openpty(&master, &slave, slname, NULL, NULL) == -1)
			err(1, "openpty");
		if (close(master) == -1)
			err(1, "close(master)");
		if (close(slave) == -1)
			err(1, "close(%s)", slname);
	}
	_exit(0);
}

int
main(void)
{
	int i, j;

	for (j = 0; j < 10; j++) {
		for (i = 0; i < 2; i++) {
			if (fork() == 0)
				pty();
		}
		for (i = 0; i < 2; i++) {
			if (fork() == 0)
				churn("/dev/pts");
		}
		for (i = 0; i < 4; i++)
			wait(NULL);
	}

	return (0);
}
