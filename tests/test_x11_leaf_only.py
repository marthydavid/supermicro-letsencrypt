"""X11 BMCs discard multi-certificate uploads on reboot, so only the leaf may be sent."""
import importlib.util
import pathlib
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location(
    "updater", pathlib.Path(__file__).resolve().parent.parent / "supermicro-ipmi-updater.py")
updater = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(updater)


def pem(label):
    return f"-----BEGIN CERTIFICATE-----\n{label}\n-----END CERTIFICATE-----\n"


class UploadPayload(unittest.TestCase):
    def upload(self, model_cls, model, bundle):
        session = mock.Mock()
        response = mock.Mock(ok=True, headers={"Content-Type": "text/html"},
                             text="CONFPAGE_RESET X-Auth")
        session.post.return_value = response
        instance = model_cls(session, "https://bmc.example")
        with tempfile.TemporaryDirectory() as tmp:
            cert, key = pathlib.Path(tmp, "c.crt"), pathlib.Path(tmp, "c.key")
            cert.write_text(bundle)
            key.write_text("KEY")
            with mock.patch.object(instance, "get_csrf_headers", return_value={}), \
                    mock.patch.object(instance, "get_csrf_token", return_value=None):
                self.assertTrue(instance.upload_cert(str(key), str(cert), model, "tok"))
        files = dict(session.post.call_args.kwargs["files"])
        return files["cert_file"][1].decode()

    def test_x11_uploads_only_the_leaf(self):
        sent = self.upload(updater.IPMIX11Updater, "X11", pem("LEAF") + pem("INTERMEDIATE") + pem("ROOT"))
        self.assertEqual(sent.count("BEGIN CERTIFICATE"), 1)
        self.assertIn("LEAF", sent)

    def test_x10_still_uploads_the_full_bundle(self):
        sent = self.upload(updater.IPMIX10Updater, "X10", pem("LEAF") + pem("INTERMEDIATE"))
        self.assertEqual(sent.count("BEGIN CERTIFICATE"), 2)


if __name__ == "__main__":
    unittest.main()
