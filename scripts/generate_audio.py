"""Reproducible original instrumental demo tracks. No downloaded recordings/samples."""
from pathlib import Path
import wave
import numpy as np
SR=44100
DURATION=48
root=Path(__file__).resolve().parents[1]/'assets'
for k in range(6):
    rng=np.random.default_rng(20261027+k)
    out=np.zeros((SR*DURATION,2),dtype=np.float64)
    scales=[[45,48,52,55],[48,52,55,59],[50,53,57,60],[43,47,50,54],[45,48,52,55],[41,45,48,52]]
    chord=scales[k]
    bpm=[80,90,72,80,110,75][k]
    beat=60/bpm
    def add(signal,start,pan=0):
        i=int(start*SR); n=min(len(signal),len(out)-i)
        if n>0:
            out[i:i+n,0]+=signal[:n]*np.sqrt((1-pan)/2)
            out[i:i+n,1]+=signal[:n]*np.sqrt((1+pan)/2)
    for bar in range(int(DURATION/(beat*4))+1):
        shift=[0,5,3,-2][bar//2%4]
        start=bar*beat*4
        t=np.arange(int(beat*4.8*SR))/SR
        envelope=np.minimum(t/.45,1)*np.minimum((t[-1]-t)/.9,1)
        for idx,note in enumerate(chord):
            f=440*2**((note+shift-69)/12)
            pad=(np.sin(2*np.pi*f*t)+.3*np.sin(2*np.pi*(f*2+.3)*t)+.15*np.sin(2*np.pi*(f*3-.2)*t))*.045*envelope
            add(pad,start,(idx-1.5)/4)
        for b in range(4):
            st=start+b*beat
            t=np.arange(int(.3*SR))/SR
            add(.19*np.sin(2*np.pi*(48*t+45*.025*(1-np.exp(-t/.025))))*np.exp(-t*18),st)
            if b%2==1:
                t=np.arange(int(.14*SR))/SR
                noise=rng.normal(0,1,len(t));noise=np.concatenate(([0],np.diff(noise)))
                add(noise*.018*np.exp(-t*35),st,.15)
            for half in range(2):
                t=np.arange(int(.065*SR))/SR
                add(rng.normal(0,1,len(t))*.010*np.exp(-t*65),st+half*beat/2,.4*(-1)**half)
        for j in range(8):
            note=chord[[0,2,1,3,2,1,3,2][j]]+shift+12
            f=440*2**((note-69)/12)
            t=np.arange(int(1.5*SR))/SR
            sig=(np.sin(2*np.pi*f*t)+.24*np.sin(2*np.pi*f*2*t))*.075*np.exp(-t*3.5)*np.minimum(t/.012,1)
            st=start+j*beat/2
            add(sig,st,(-1)**j*.25)
            add(sig*.22,st+beat*.75,(-1)**(j+1)*.55)
    fade=np.minimum(np.arange(len(out))/(SR*1.5),1)*np.minimum(np.arange(len(out))[::-1]/(SR*3),1)
    out*=fade[:,None]
    out=np.tanh(out*1.4)
    out=out/max(np.max(np.abs(out)),.001)*.82
    with wave.open(str(root/f'track-{k}.wav'),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes((out*32767).astype('<i2').tobytes())
    print(f'Generated original {k+1}/6')
