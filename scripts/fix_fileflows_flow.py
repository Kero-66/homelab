#!/usr/bin/env python3
import json

with open('/mnt/library/repos/homelab/media/fileflows/Data/Config/Flows/YouTube Download.json', 'r') as f:
    data = json.load(f)

for part in data['Parts']:
    if part.get('Model', {}).get('Code'):
        code = part['Model']['Code']
        if '--no-playlist' in code and 'argumentList' in code:
            old_dump = """argumentList: [
		'--no-playlist',"""
            new_dump = """argumentList: [
		'--js-runtimes',
		'node',
		'--no-playlist',"""
            code = code.replace(old_dump, new_dump)
            
            old_download = """argumentList: [
		'-o',
		output,
		'--ffmpeg-location',
		ffmpeg,
		'--embed-thumbnail',
		'-t', 'mkv',
		//'--sponsorblock-remove',
		//'all',
		'--no-playlist',"""
            new_download = """argumentList: [
		'-o',
		output,
		'--js-runtimes',
		'node',
		'--ffmpeg-location',
		ffmpeg,
		'--embed-thumbnail',
		'-t', 'mkv',
		//'--sponsorblock-remove',
		//'all',
		'--no-playlist',"""
            code = code.replace(old_download, new_download)
            part['Model']['Code'] = code
            print("Updated Code")

with open('/mnt/library/repos/homelab/media/fileflows/Data/Config/Flows/YouTube Download.json', 'w') as f:
    json.dump(data, f, indent=2)
print("Saved")
