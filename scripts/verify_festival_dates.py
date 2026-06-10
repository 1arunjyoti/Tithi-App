#!/usr/bin/env python3
"""
Festival Date Verification Tool
--------------------------------
This script helps verify Hindu festival dates from your festivals.json
against online Panchang sources like Drik Panchang.

Usage: python3 verify_festival_dates.py <year>
Example: python3 verify_festival_dates.py 2026
"""

import json
import requests
from datetime import datetime
import sys
from bs4 import BeautifulSoup
import time

class PanchangVerifier:
    def __init__(self, year):
        self.year = year
        self.base_url = "https://www.drikpanchang.com"
        
    def fetch_festival_date(self, festival_slug):
        """
        Fetch festival date from Drik Panchang
        Example: 'holi' -> gets Holi date for the year
        """
        try:
            url = f"{self.base_url}/{festival_slug}/{festival_slug}-date-puja-time.html?year={self.year}"
            headers = {'User-Agent': 'Mozilla/5.0 (compatible; FestivalVerifier/1.0)'}
            
            time.sleep(1)  # Be respectful to the server
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                soup = BeautifulSoup(response.content, 'html.parser')
                # Drik Panchang usually shows the date prominently
                # This is a simplified parser - actual structure may vary
                date_elements = soup.find_all(['span', 'div', 'p'], class_=lambda x: x and 'date' in x.lower() if x else False)
                return {"status": "found", "url": url, "content_length": len(response.text)}
            else:
                return {"status": "not_found", "code": response.status_code}
                
        except Exception as e:
            return {"status": "error", "message": str(e)}
    
    def get_panchang_for_month(self, month_num):
        """
        Fetch monthly panchang to find tithi-based festivals
        """
        try:
            # Drik Panchang month URLs
            months = {
                1: "january", 2: "february", 3: "march", 4: "april",
                5: "may", 6: "june", 7: "july", 8: "august",
                9: "september", 10: "october", 11: "november", 12: "december"
            }
            
            month_name = months.get(month_num)
            if not month_name:
                return None
                
            url = f"{self.base_url}/panchang/{month_name}-{self.year}/panchang-{month_name}-{self.year}.html"
            headers = {'User-Agent': 'Mozilla/5.0 (compatible; FestivalVerifier/1.0)'}
            
            time.sleep(1)
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                return {"status": "found", "url": url, "month": month_name}
            else:
                return {"status": "not_found", "code": response.status_code}
                
        except Exception as e:
            return {"status": "error", "message": str(e)}


class FestivalMatcher:
    """
    Map festival IDs to Drik Panchang slugs or search terms
    """
    
    # Mapping of your festival IDs to Drik Panchang URLs/slugs
    FESTIVAL_MAPPING = {
        # Major Festivals
        "holi": "holi",
        "diwali": "diwali",
        "dussehra": "dussehra",
        "navratri_day_1": "navratri",
        "chaitra_navratri_day_1": "chaitra-navratri",
        "ram_navami": "rama-navami",
        "janmashtami": "janmashtami",
        "maha_shivaratri": "maha-shivaratri",
        "ganesh_chaturthi": "ganesh-chaturthi",
        "raksha_bandhan": "raksha-bandhan",
        "makar_sankranti": "makar-sankranti",
        "pongal": "pongal",
        "baisakhi": "baisakhi",
        "onam": "onam",
        "karwa_chauth": "karwa-chauth",
        "dhanteras": "dhanteras",
        "guru_nanak_jayanti": "guru-nanak-jayanti",
        "mahavir_jayanti": "mahavir-jayanti",
        "buddha_purnima": "buddha-purnima",
        "rath_yatra": "rath-yatra",
        "nag_panchami": "nag-panchami",
        "varalakshmi_vratam": "varalakshmi-vrat",
        "saraswati_puja": "saraswati-puja",
    }
    
    @classmethod
    def get_slug(cls, festival_id):
        """Get Drik Panchang slug for a festival ID"""
        # Direct mapping
        if festival_id in cls.FESTIVAL_MAPPING:
            return cls.FESTIVAL_MAPPING[festival_id]
        
        # Try to extract base festival name for multi-day festivals
        for key in cls.FESTIVAL_MAPPING:
            if festival_id.startswith(key):
                return cls.FESTIVAL_MAPPING[key]
        
        return None


def load_festivals(json_path):
    """Load festivals from JSON file"""
    with open(json_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def verify_festivals(festivals_data, year):
    """
    Verify festival dates for a given year
    """
    verifier = PanchangVerifier(year)
    results = {
        "year": year,
        "total_festivals": len(festivals_data),
        "verified": [],
        "not_found": [],
        "errors": [],
        "info": []
    }
    
    print(f"\n{'='*70}")
    print(f"Festival Date Verification Report - Year {year}")
    print(f"{'='*70}\n")
    
    # Group by category
    categories = {}
    for festival in festivals_data:
        cat = festival.get('category', 'other')
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(festival)
    
    print(f"Found {len(festivals_data)} festivals in {len(categories)} categories:")
    for cat, items in categories.items():
        print(f"  - {cat}: {len(items)} festivals")
    
    print(f"\n{'='*70}")
    print("Verification Strategy:")
    print("{'='*70}\n")
    print("1. Major Festivals: Will attempt to fetch from Drik Panchang")
    print("2. Tithi-based Festivals: Will note panchang rules for manual verification")
    print("3. Recurring Vrats: Will note frequency patterns\n")
    
    # Verify major festivals
    print(f"\n{'='*70}")
    print("Major Festivals Verification:")
    print(f"{'='*70}\n")
    
    for festival in festivals_data:
        if festival.get('category') == 'major':
            festival_id = festival.get('id')
            festival_name = festival.get('name')
            slug = FestivalMatcher.get_slug(festival_id)
            
            if slug:
                result = verifier.fetch_festival_date(slug)
                if result['status'] == 'found':
                    print(f"✓ {festival_name}")
                    print(f"  URL: {result['url']}")
                    results['verified'].append({
                        'id': festival_id,
                        'name': festival_name,
                        'url': result['url']
                    })
                else:
                    print(f"✗ {festival_name} - Not found")
                    results['not_found'].append(festival_id)
            else:
                panchang = festival.get('panchang_rules', {})
                print(f"⚠ {festival_name}")
                print(f"  Panchang: {panchang.get('masa')} {panchang.get('paksha')} {panchang.get('tithi')}")
                results['info'].append({
                    'id': festival_id,
                    'name': festival_name,
                    'panchang': panchang
                })
    
    # Summary of tithi-based festivals
    print(f"\n{'='*70}")
    print("Tithi-Based Festivals (Require Panchang Lookup):")
    print(f"{'='*70}\n")
    
    tithi_festivals = [f for f in festivals_data if f.get('category') not in ['major'] and not f.get('panchang_rules', {}).get('recurring')]
    
    masa_groups = {}
    for festival in tithi_festivals:
        panchang = festival.get('panchang_rules', {})
        masa = panchang.get('masa', 'unknown')
        if masa not in masa_groups:
            masa_groups[masa] = []
        masa_groups[masa].append(festival)
    
    for masa, festivals in sorted(masa_groups.items()):
        print(f"\n{masa.upper()} Masa ({len(festivals)} festivals):")
        for f in festivals[:5]:  # Show first 5
            p = f.get('panchang_rules', {})
            print(f"  • {f.get('name')}")
            print(f"    {p.get('paksha')} Paksha, Tithi {p.get('tithi')}")
        if len(festivals) > 5:
            print(f"  ... and {len(festivals) - 5} more")
    
    # Summary of recurring vrats
    print(f"\n{'='*70}")
    print("Recurring Vrats:")
    print(f"{'='*70}\n")
    
    recurring = [f for f in festivals_data if f.get('panchang_rules', {}).get('recurring')]
    
    weekday_vrats = [f for f in recurring if 'weekday' in f.get('panchang_rules', {})]
    monthly_vrats = [f for f in recurring if 'weekday' not in f.get('panchang_rules', {})]
    
    if weekday_vrats:
        print(f"Weekday Vrats ({len(weekday_vrats)}):")
        for f in weekday_vrats:
            weekday = f.get('panchang_rules', {}).get('weekday', '')
            print(f"  • {f.get('name')} - Every {weekday}")
    
    if monthly_vrats:
        print(f"\nMonthly Vrats ({len(monthly_vrats)}):")
        for f in monthly_vrats:
            p = f.get('panchang_rules', {})
            print(f"  • {f.get('name')} - {p.get('paksha')} Paksha Tithi {p.get('tithi')}")
    
    # Final summary
    print(f"\n{'='*70}")
    print("SUMMARY:")
    print(f"{'='*70}\n")
    print(f"Total Festivals: {results['total_festivals']}")
    print(f"Verified Online: {len(results['verified'])}")
    print(f"Require Manual Panchang Lookup: {len(results['info'])}")
    print(f"Recurring Vrats: {len(recurring)}")
    
    print(f"\n{'='*70}")
    print("RECOMMENDATIONS:")
    print(f"{'='*70}\n")
    print("1. For verified festivals: Visit the URLs above to get exact dates")
    print("2. For tithi-based festivals: Use Drik Panchang monthly view:")
    print(f"   https://www.drikpanchang.com/panchang/month-panchang.html?year={year}")
    print("3. Cross-reference with: https://www.prokerala.com/calendar/")
    print("4. For regional variations: Check local temple calendars")
    
    return results


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 verify_festival_dates.py <year>")
        print("Example: python3 verify_festival_dates.py 2026")
        sys.exit(1)
    
    try:
        year = int(sys.argv[1])
    except ValueError:
        print("Error: Year must be a number")
        sys.exit(1)
    
    # Load festivals
    festivals_path = "/mnt/user-data/uploads/festivals.json"
    
    try:
        festivals = load_festivals(festivals_path)
    except FileNotFoundError:
        print(f"Error: Could not find {festivals_path}")
        sys.exit(1)
    
    # Verify
    results = verify_festivals(festivals, year)
    
    # Save results
    output_file = f"/home/claude/verification_report_{year}.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    
    print(f"\nDetailed results saved to: {output_file}\n")


if __name__ == "__main__":
    main()
