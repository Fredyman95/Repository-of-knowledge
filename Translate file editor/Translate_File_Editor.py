import json
import os
import re

def sync_preserving_everything(old_filename, crowdin_filename, output_filename):
    base_path = os.path.dirname(os.path.abspath(__file__))
    old_path = os.path.join(base_path, old_filename)
    crowdin_path = os.path.join(base_path, crowdin_filename)
    output_path = os.path.join(base_path, output_filename)

    try:
        with open(crowdin_path, 'r', encoding='utf-8') as f:
            crowdin_data = json.load(f)
        
        with open(old_path, 'r', encoding='utf-8') as f:
            old_content = f.read()

        def replace_value(match):
            key = match.group(1)
            if key in crowdin_data:
                new_val = str(crowdin_data[key]).replace('"', '\\"')
                return f'"{key}": "{new_val}"'
            return match.group(0)

        pattern = r'"([^"]+)":\s*"[^"]*"'
        
        final_content = re.sub(pattern, replace_value, old_content)

        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(final_content)
            
        print(f"Task finished - file 'en.json' is generated.")

    except Exception as e:
        print(f"Error: {e}")

sync_preserving_everything('old.json', 'crowdin.json', 'en_us.json')
