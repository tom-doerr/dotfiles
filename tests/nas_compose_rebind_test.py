"""The port rewriter must handle every form the NAS compose files actually use, and refuse the rest."""
import importlib.util, os, unittest
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_loader("nas_compose_rebind", loader=None)
m = importlib.util.module_from_spec(spec)
with open(os.path.join(HERE, "..", "scripts", "nas-compose-rebind")) as f:
    exec(compile(f.read(), "nas-compose-rebind", "exec"), m.__dict__)  # noqa: S102


class Rewrite(unittest.TestCase):
    def test_every_real_form_gets_loopback_plus_tailscale(self):
        src = ('services:\n  x:\n    ports:\n      - "9000:9000"\n      - 5434:5432\n'
               '      - "0.0.0.0:5434:5432"\n      - ${IMMICH_PORT:-2283}:2283\n      - "4317:4317/tcp"   # otlp\n'
               '    environment:\n      - FOO=1\n')
        new, changed = m.rewrite(src)
        self.assertEqual(changed, 5)
        self.assertIn('      - "127.0.0.1:9000:9000"\n      - "100.85.146.21:9000:9000"', new)
        self.assertIn('      - 127.0.0.1:5434:5432\n      - 100.85.146.21:5434:5432', new)
        self.assertIn('"127.0.0.1:${IMMICH_PORT:-2283}:2283"', new, 'variables must come out quoted')
        self.assertIn('"127.0.0.1:4317:4317/tcp"   # otlp', new)
        self.assertNotIn('0.0.0.0', new)
        self.assertIn('      - FOO=1', new, 'lines outside ports: untouched')

    def test_a_variable_bind_prefix_defaulting_to_all_interfaces_is_replaced(self):
        """mlflow: `"${MLFLOW_BIND:-0.0.0.0}:5010:5000"` — the variable IS the bind address decision."""
        new, changed = m.rewrite('ports:\n  - "${MLFLOW_BIND:-0.0.0.0}:5010:5000"\n')
        self.assertEqual(changed, 1)
        self.assertIn('- "127.0.0.1:5010:5000"\n  - "100.85.146.21:5010:5000"', new)
        self.assertNotIn('MLFLOW_BIND', new)

    def test_idempotent_on_a_file_already_rebound(self):
        src = 'ports:\n  - "127.0.0.1:9090:9090"\n  - "100.85.146.21:9090:9090"\n'
        new, changed = m.rewrite(src)
        self.assertEqual((new, changed), (src, 0))

    def test_an_unparseable_ports_entry_refuses_instead_of_skipping(self):
        with self.assertRaises(ValueError):
            m.rewrite('ports:\n  - "192.168.8.204:9090:9090"\n')

    def test_a_dash_outside_ports_is_not_a_port(self):
        new, changed = m.rewrite('volumes:\n  - "9000:9000"\n')
        self.assertEqual(changed, 0)


if __name__ == "__main__": unittest.main()
