from LDDC.core.api.lyrics import search, get_lyrics
from LDDC.common.models import Source, SearchType
import os
import argparse

def save_lrc(song, lrc_text, save_path="."):
    filename = f"{song.artist} - {song.title}.lrc"
    filename = "".join(c for c in filename if c not in r'\/:*?"<>|')
    filepath = os.path.join(save_path, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(lrc_text)
    print(f"已保存: {filepath}")

def convert_to_lrc(lyric):
    lrc_text = ""
    for line in lyric['orig']:
        words = line.words
        if words:
            start_time = line.start
            text = "".join([word.text for word in words])
            minutes = start_time // 60000
            seconds = (start_time % 60000) // 1000
            milliseconds = start_time % 1000
            lrc_line = f"[{minutes:02d}:{seconds:02d}.{milliseconds:03d}]{text}\n"
            lrc_text += lrc_line
    return lrc_text

def download_lyrics(song_name, save_path="."):
    result = search(Source.QM, song_name, SearchType.SONG)
    for song in result:
        print(f"{song.title} - {song.artist}")
        try:
            lyric = get_lyrics(song)
            lrc_text = convert_to_lrc(lyric)
            if lrc_text:
                save_lrc(song, lrc_text, save_path)
            else:
                print("未找到歌词")
        except Exception as e:
            print(f"获取歌词失败: {e}")
        break  # 只保存第一首，去掉break可批量保存

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download lyrics for a song.")
    parser.add_argument("song_name", type=str, nargs="?", default="周杰伦 稻香", help="Name of the song (default: 周杰伦 稻香)")
    parser.add_argument("--save_path", type=str, default="./lyrics_temp", help="Directory to save lyrics")
    args = parser.parse_args()

    os.makedirs(args.save_path, exist_ok=True)  # 确保保存路径存在
    download_lyrics(args.song_name, args.save_path)


