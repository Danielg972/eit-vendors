# D-62 / D-63: prints the production probe with the migration put in at the line marked @migration, as one statement, so it
# can be run on production before the migration is (everything, the migration included, is rolled back by the probe's last
# line). Only with the owner's word.
#   python3 supabase/tests/online_links_hebrew/run_probe.py > probe_with_migration.sql
import pathlib
here = pathlib.Path(__file__).resolve().parent
mig = (here / '../../migrations/2026-10-25_online_links_hebrew_names.sql').resolve().read_text()
probe = (here / 'production_probe.sql').read_text()
assert '$mig$' not in mig and probe.count('-- @migration') == 1
print(probe.replace('-- @migration', 'execute $mig$\n' + mig + '\n$mig$;'), end='')
