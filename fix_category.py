import re

with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Messages/Views/SharedCardView.swift', 'r') as f:
    content = f.read()

# Replace matchedChallenge.category with matchedChallenge.type
fix = """
                // Determine category and icon
                let typeStr = matchedChallenge.type.lowercased()
                category = matchedChallenge.type.capitalized + " challenge"
                if typeStr == "sleep" {
                    iconName = "moon.zzz.fill"
                    totalDesc = "hours"
                } else if typeStr == "fitness" || typeStr == "distance" {
                    iconName = "figure.run"
                    totalDesc = "km"
                } else {
                    iconName = "figure.walk"
                    totalDesc = "steps"
                }
"""

content = re.sub(r'                // Determine category and icon\n                category = matchedChallenge.category.*?                \}', fix, content, flags=re.DOTALL)

with open('/Users/mani16/Downloads/ProjectiOS 2/HomeScreen/Messages/Views/SharedCardView.swift', 'w') as f:
    f.write(content)
