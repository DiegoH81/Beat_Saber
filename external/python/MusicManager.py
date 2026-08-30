import sys

import MusicLoader as loader
import InfoGenerator as info



class MusicManager:
    def __init__(self, in_output_music : str, in_output_level : str, in_song_path : str, in_is_url : bool):
        self.m_loader = loader.MusicLoader(in_output_music)
        self.m_info = info.MusicAnalyzer(in_output_level)
        self.song_path = in_song_path
        self.is_url = in_is_url
        
    def load_song(self):
        
        new_song_path = ""
        
        if (self.is_url == True):
            new_song_path = self.m_loader.load_internet(self.song_path)
        else:
            new_song_path = self.m_loader.load_local(self.song_path)
            
        self.m_info.analyze_audio(new_song_path)
        
        
if __name__ == "__main__":
    if len(sys.argv) >= 5:
        folder_music = sys.argv[1]
        folder_info = sys.argv[2]
        song_path = sys.argv[3]
        isUrl = sys.argv[4].lower() in ("true", "1")
        
        manager = MusicManager(folder_music, folder_info, song_path, isUrl)
        manager.load_song()
    else:
        print("Python takes 4 args: folder music, folder info, song path, isUrl")