import re

files = [
    "HomeScreen/Auth/SignupFamilyViewController.swift",
    "HomeScreen/Auth/LoginSignupViewController.swift"
]

old_pattern = r"""    private lazy var backButton: UIButton = \{
        let button = UIButton\(type: \.system\)
        let config = UIImage\.SymbolConfiguration\(pointSize: 22, weight: \.medium\)
        button\.setImage\(UIImage\(systemName: "chevron\.backward", withConfiguration: config\), for: \.normal\)
        button\.tintColor = \.systemBlue
        button\.translatesAutoresizingMaskIntoConstraints = false
        button\.addTarget\(self, action: #selector\(backTapped\), for: \.touchUpInside\)
        return button
    \}\(\)"""

new_button = """    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        button.tintColor = .label
        
        let blurEffect = UIBlurEffect(style: .systemThickMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerRadius = 20
        blurView.layer.borderWidth = 0.5
        blurView.layer.borderColor = UIColor.systemGray4.cgColor
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        
        button.insertSubview(blurView, at: 0)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: button.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return button
    }()"""

for f in files:
    with open(f, "r") as file:
        content = file.read()
    
    content = re.sub(old_pattern, new_button, content)
    
    if "SignupFamilyViewController" in f:
        # Align with pad = 18 for Signup, Create, Join Family
        content = re.sub(r'backButton\.leadingAnchor\.constraint\(equalTo: view\.safeAreaLayoutGuide\.leadingAnchor, constant: \d+\)', 
                         r'backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18)', content)
    else:
        # For LoginSignupViewController align with card (24)
        content = re.sub(r'backButton\.leadingAnchor\.constraint\(equalTo: view\.safeAreaLayoutGuide\.leadingAnchor, constant: \d+\)', 
                         r'backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24)', content)
    
    with open(f, "w") as file:
        file.write(content)

print("Done style fix.")
