"""Check cleanup ordering and cached-object preservation without loading models."""
import importlib.util
from pathlib import Path
import unittest
import weakref

SCRIPT = Path(__file__).resolve().parents[1] / 'mpv-sr/seedvr2_run.py'
spec = importlib.util.spec_from_file_location('seedvr2_run', SCRIPT)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class Model:
    pass


class CleanupTest(unittest.TestCase):
    def test_releases_after_disposal_and_preserves_cached_models(self):
        for cache in (False, True):
            owner = Model()
            owner.model = Model()
            ref = weakref.ref(owner.model)
            calls = []

            def upstream(owner, cache_model):
                if not cache_model:
                    owner.model = None
                return 'done'

            def clear(**kwargs):
                self.assertEqual(kwargs, {'deep': True, 'force': True})
                self.assertEqual(ref() is not None, cache)
                calls.append('released')

            wrapped = runner.with_memory_release(upstream, clear)
            self.assertEqual(wrapped(owner, cache_model=cache), 'done')
            self.assertEqual(calls, ['released'])
            if cache:
                self.assertIs(owner.model, ref())

    def test_upstream_errors_are_preserved(self):
        def upstream():
            raise RuntimeError('cleanup failed')

        def clear(**kwargs):
            self.fail('must not mask an upstream cleanup failure')

        with self.assertRaisesRegex(RuntimeError, 'cleanup failed'):
            runner.with_memory_release(upstream, clear)()


if __name__ == '__main__':
    unittest.main()
