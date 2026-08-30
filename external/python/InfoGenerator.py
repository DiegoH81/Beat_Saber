import os
import librosa
import numpy as np

class MusicAnalyzer:
    def __init__(self, in_output_dir: str):
        self.output_dir = in_output_dir

    def analyze_audio(self, in_source_audio: str):
        y, sr = librosa.load(in_source_audio)
        duration = librosa.get_duration(y=y, sr=sr)
        
        bpm, _ = librosa.beat.beat_track(y=y, sr=sr)
        if isinstance(bpm, np.ndarray):
            bpm = bpm[0]
            
        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        
        beat_duration_sec = 60.0 / float(bpm)
        min_sec_between_notes = beat_duration_sec / 2.0 
        hop_length = 512
        frames_per_sec = sr / hop_length
        wait_frames = max(1, int(min_sec_between_notes * frames_per_sec))
        
        dynamic_delta = np.percentile(onset_env, 50) * 0.2
        
        onset_frames = librosa.onset.onset_detect(
            onset_envelope=onset_env,
            sr=sr,
            hop_length=hop_length,
            backtrack=False,
            delta=dynamic_delta,
            wait=wait_frames
        )
        
        if len(onset_frames) < (duration * 0.8):
            _, beat_frames = librosa.beat.beat_track(y=y, sr=sr, hop_length=hop_length)
            onset_frames = beat_frames

        onset_times = librosa.frames_to_time(onset_frames, sr=sr, hop_length=hop_length)
        
        stft = np.abs(librosa.stft(y, hop_length=hop_length))
        frequencies = librosa.fft_frequencies(sr=sr)
        
        events = []
        for frame, t in zip(onset_frames, onset_times):
            if frame < stft.shape[1]:
                magnitude_column = stft[:, frame]
                max_bin = np.argmax(magnitude_column)
                dominant_freq = frequencies[max_bin]
                
                events.append((round(float(t), 3), round(float(dominant_freq), 1)))
        
        song_file_name = os.path.basename(in_source_audio)
        song_base_name, _ = os.path.splitext(song_file_name)
        
        txt_output_path = os.path.join(self.output_dir, f"{song_base_name}.txt")
        os.makedirs(self.output_dir, exist_ok=True)
        
        with open(txt_output_path, 'w', encoding='utf-8') as f:
            f.write("DATA\n")
            f.write(f"SongName = {song_file_name}\n")
            f.write(f"BPM = {round(float(bpm), 2)}\n")
            f.write(f"Duration = {round(float(duration), 2)}\n")
            f.write(f"TotalEvents = {len(events)}\n\n")
            
            f.write("Events\n")
            for t, freq in events:
                f.write(f"{t:.3f} | {freq}\n")