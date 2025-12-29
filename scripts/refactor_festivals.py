import json
import os

# Adjust paths to be absolute or relative to where we run it.
# We will run from d:\Projects\Tithi_Project\tithi
input_path = 'assets/festivals.json'
output_path = 'assets/festivals_refactored.json'

def transform_entry(entry):
    # Check if already in new format by checking for 'visuals' key
    if 'visuals' in entry:
        # It's already the new format, but let's ensure all fields are present just in case
        return entry

    new_entry = {}
    
    # 1. ID
    new_entry['id'] = entry.get('id', '')
    
    # 2. Name
    new_entry['name'] = entry.get('name', '')
    
    # 3. Category
    new_entry['category'] = entry.get('category', 'major')

    # 4. Name Regional
    new_entry['nameRegional'] = {
        "nameSanskrith": "", # Can't easily infer
        "nameEnglish": entry.get('name', ''),
        "nameHindi": entry.get('nameHindi', ''),
        "nameBengali": entry.get('nameBengali', ''),
        "nameTelugu": "",
        "nameKannada": "",
        "nameTamil": "",
        "nameMalayalam": ""
    }

    # 5. Visuals
    new_entry['visuals'] = {
        "image": "",
        "theme_color": ""
    }

    # 6. Purpose
    new_entry['purpose'] = {
        "description": entry.get('description', ''),
        "addtional_description": entry.get('addtional_description', '')
    }

    # 7. Panchang Rules
    panchang_rules = {
        "masa": entry.get('masa', ''),
        "paksha": entry.get('paksha', ''),
        "tithi": entry.get('tithi', 0),
        "conditions": entry.get('conditions', '')
    }
    
    # Move other scheduling fields if present
    if 'solarDate' in entry:
        panchang_rules['solarDate'] = entry['solarDate']
    if 'weekday' in entry:
        panchang_rules['weekday'] = entry['weekday']
    if 'recurring' in entry:
        panchang_rules['recurring'] = entry['recurring']

    new_entry['panchang_rules'] = panchang_rules

    # 8. Rituals
    # In old format, rituals is a list of strings
    new_entry['rituals'] = {
        "steps": entry.get('rituals', []),
        "mantra": "",
        "fasting": ""
    }

    # 9. Media
    new_entry['media'] = {
        "audio_stotra": ""
    }

    return new_entry

def main():
    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found")
        return

    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    new_data = [transform_entry(entry) for entry in data]

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(new_data, f, indent=2, ensure_ascii=False)
    
    print(f"Successfully processed {len(new_data)} entries.")

if __name__ == '__main__':
    main()
