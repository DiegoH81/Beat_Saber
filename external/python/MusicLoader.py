import os
import yt_dlp
import shutil

class MusicLoader:
    def __init__(self, in_output_dir):
        self.output_dir = in_output_dir
        os.makedirs(self.output_dir, exist_ok = True)
    
    def load_local(self, source: str):
        
        if not os.path.exists(source):
            raise FileNotFoundError(f"File {source} does not exists!")
        
        file_name = os.path.basename(source)
        output_path = os.path.join(self.output_dir, file_name)
        
        shutil.copy(source, output_path)
        
        return output_path
    
    def load_internet(self, url: str):
        
        out_template = os.path.join(self.output_dir, "%(title)s.%(ext)s")
        ydl_opts = {
            'format': 'bestaudio/best',
            'outtmpl': out_template,
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '192',
            }],
            'quiet': True,
            'restrictfilenames': True, 
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            file_name = ydl.prepare_filename(info)
            
            base_path, _ = os.path.splitext(file_name)
            final_mp3_path = f"{base_path}.mp3"
            
            return final_mp3_path