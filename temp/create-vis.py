from pathlib import Path
root = Path("C:/Users/svelderr/repo/labview-icon-editor-sandbox")
temp = root / "temp"
temp.mkdir(parents=True, exist_ok=True)
def write_vi(name, version):
    path = temp / name
    data = bytearray(12)
    data[0:4] = b"RSRC"
    data[8:12] = version.to_bytes(4, "little")
    path.write_bytes(data)
write_vi("BaseVI.vi", 0x0F000000)
write_vi("CompareVI.vi", 0x10000000)
