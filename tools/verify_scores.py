"""Inspect delivered PCM independently of the composing code. Python + NumPy."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
EXPECTED={"skybound.wav":40,"moss_and_fireflies.wav":80,"steps_of_amber.wav":96,"a_path_through_stars.wav":128*60/104}
checks=0
levels=[]
hashes=[]
report={}


def check(condition,description):
    global checks
    checks+=1
    assert condition, description
    print("PASS "+description)


for name,seconds in EXPECTED.items():
    path=ROOT/"assets/music"/name
    with wave.open(str(path),"rb") as stream:
        rate=stream.getframerate()
        check((stream.getnchannels(),stream.getsampwidth(),rate)==(2,2,44100),name+": stereo 44.1 kHz 16-bit PCM")
        check(abs(stream.getnframes()/rate-seconds)<1/rate,name+": complete score duration")
        samples=np.frombuffer(stream.readframes(stream.getnframes()),dtype="<i2").astype(np.float64).reshape(-1,2)/32768
    peak=float(np.max(np.abs(samples)))
    rms=float(np.sqrt(np.mean(samples*samples)))
    quietest=min(float(np.sqrt(np.mean(samples[i:i+rate]**2))) for i in range(0,len(samples),rate))
    boundary=float(np.max(np.abs(samples[0]-samples[-1])))
    check(.65<peak<.8 and not np.any(np.abs(samples)>=.999),name+": headroom without clipped PCM")
    check(20*np.log10(rms)>-22 and 20*np.log10(quietest)>-34,name+": no unintended silent section")
    check(boundary<.01,name+": continuous loop seam")
    check(abs(float(np.mean(samples)))<.001,name+": negligible DC offset")
    check(float(np.sqrt(np.mean((samples[:,0]-samples[:,1])**2)))>.005,name+": distinct stereo channels")
    levels.append(float(20*np.log10(rms)))
    hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
    report[name]={"seconds":len(samples)/rate,"rms_dbfs":round(levels[-1],3),"peak":round(peak,5),"boundary_step":round(boundary,6),"sha256":hashes[-1]}
check(max(levels)-min(levels)<1.5,"Menu and chapter scores have comparable average levels")
check(len(set(hashes))==4,"All four scores contain different PCM data")
print("SCORE RESULT: %d/%d passed" % (checks,checks))
print(json.dumps(report,indent=2))
