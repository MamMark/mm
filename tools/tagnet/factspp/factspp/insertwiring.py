def find_insert(f):
    f.seek(0)
    count = 0


for line in f.readlines():
    if (line.startswith('# >>>>')):
        print('found it at line: {}'.format(count))
    count += 1
