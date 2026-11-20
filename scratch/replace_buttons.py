import re

file_path = "HomeScreen/Auth/SignupFamilyViewController.swift"
with open(file_path, "r") as f:
    content = f.read()

# 1. We replace backButton with loginButton for the two classes.
login_button_code = """    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Already a Member? Log in", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()"""

back_button_pattern = r"""    private lazy var backButton: UIButton = \{
        var config = UIButton\.Configuration\.plain\(\)
        config\.image = UIImage\(systemName: "chevron\.left", withConfiguration: UIImage\.SymbolConfiguration\(pointSize: 16, weight: \.semibold\)\)
        config\.baseForegroundColor = \.label
        config\.background\.visualEffect = UIBlurEffect\(style: \.systemThickMaterial\)
        config\.background\.strokeColor = \.systemGray4
        config\.background\.strokeWidth = 0\.5
        config\.cornerStyle = \.capsule
        
        let button = UIButton\(configuration: config\)
        button\.translatesAutoresizingMaskIntoConstraints = false
        button\.addTarget\(self, action: #selector\(backTapped\), for: \.touchUpInside\)
        
        NSLayoutConstraint\.activate\(\[
            button\.widthAnchor\.constraint\(equalToConstant: 40\),
            button\.heightAnchor\.constraint\(equalToConstant: 40\)
        \]\)
        
        return button
    \}\(\)"""

# Find all occurrences of backButton pattern
occurrences = [m.start() for m in re.finditer(back_button_pattern, content)]
# There are 3 occurrences: SignupFamily, JoinFamily, CreateFamily
# We only want to replace the 2nd and 3rd ones.
if len(occurrences) == 3:
    part1 = content[:occurrences[1]]
    part2 = content[occurrences[1]:occurrences[2]].replace(re.search(back_button_pattern, content).group(), login_button_code)
    part3 = content[occurrences[2]:].replace(re.search(back_button_pattern, content).group(), login_button_code)
    content = part1 + part2 + part3
else:
    print("Could not find 3 occurrences of backButton!")

# 2. Remove backTapped from Join and Create (which are at the bottom of the classes)
# Actually, loginButton needs to go to login screen. It can do this by popping if it's pushed from login, or dismissing if presented. Both do the exact same thing as backTapped!
# So we can just rename backTapped to loginTapped for Join and Create!
# In part2/3 (Join and Create), rename "func backTapped()" to "func loginTapped()"
# Wait, let's just do it directly.

# Re-read content
def fix_vc(class_name, class_content, card_container_name):
    class_content = class_content.replace(
        "view.addSubview(backButton)\n", ""
    )
    # Remove backButton constraints
    class_content = re.sub(r'\s*backButton\.topAnchor\.constraint\(equalTo: view\.safeAreaLayoutGuide\.topAnchor, constant: 16\),', '', class_content)
    class_content = re.sub(r'\s*backButton\.topAnchor\.constraint\(equalTo: view\.safeAreaLayoutGuide\.topAnchor, constant: 18\),', '', class_content)
    class_content = re.sub(r'\s*backButton\.leadingAnchor\.constraint\(equalTo: view\.safeAreaLayoutGuide\.leadingAnchor, constant: 16\),', '', class_content)
    class_content = re.sub(r'\s*backButton\.leadingAnchor\.constraint\(equalTo: view\.safeAreaLayoutGuide\.leadingAnchor, constant: 18\),', '', class_content)
    
    # Add loginButton to container
    class_content = class_content.replace(
        "signupButton.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)",
        f"signupButton.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)\n        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)\n        {card_container_name}.addSubview(loginButton)"
    )
    
    # Replace statusLabel bottom constraint
    class_content = class_content.replace(
        f"statusLabel.bottomAnchor.constraint(equalTo: {card_container_name}.bottomAnchor, constant: -24)",
        f"loginButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),\n            loginButton.centerXAnchor.constraint(equalTo: {card_container_name}.centerXAnchor),\n            loginButton.bottomAnchor.constraint(equalTo: {card_container_name}.bottomAnchor, constant: -20)"
    )
    
    # Rename backTapped to loginTapped
    class_content = class_content.replace("func backTapped()", "func loginTapped()")
    
    return class_content

# Split content by class
join_split = content.find("final class JoinFamilyViewController")
create_split = content.find("final class CreateFamilyViewController")

part_signup = content[:join_split]
part_join = content[join_split:create_split]
part_create = content[create_split:]

part_join = fix_vc("JoinFamilyViewController", part_join, "cardView")
part_create = fix_vc("CreateFamilyViewController", part_create, "formContainer")

content = part_signup + part_join + part_create

with open(file_path, "w") as f:
    f.write(content)

print("Done python script")
