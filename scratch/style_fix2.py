import re

files = [
    "HomeScreen/Auth/SignupFamilyViewController.swift",
    "HomeScreen/Auth/LoginSignupViewController.swift"
]

old_pattern = r"""    private lazy var backButton: UIButton = \{
        let button = UIButton\(type: \.system\)
        let config = UIImage\.SymbolConfiguration\(pointSize: 16, weight: \.semibold\)
        button\.setImage\(UIImage\(systemName: "chevron\.left", withConfiguration: config\), for: \.normal\)
        button\.tintColor = \.label
        
        let blurEffect = UIBlurEffect\(style: \.systemThickMaterial\)
        let blurView = UIVisualEffectView\(effect: blurEffect\)
        blurView\.isUserInteractionEnabled = false
        blurView\.layer\.cornerRadius = 20
        blurView\.layer\.borderWidth = 0\.5
        blurView\.layer\.borderColor = UIColor\.systemGray4\.cgColor
        blurView\.clipsToBounds = true
        blurView\.translatesAutoresizingMaskIntoConstraints = false
        
        button\.insertSubview\(blurView, at: 0\)
        button\.translatesAutoresizingMaskIntoConstraints = false
        button\.addTarget\(self, action: #selector\(backTapped\), for: \.touchUpInside\)
        
        NSLayoutConstraint\.activate\(\[
            blurView\.topAnchor\.constraint\(equalTo: button\.topAnchor\),
            blurView\.bottomAnchor\.constraint\(equalTo: button\.bottomAnchor\),
            blurView\.leadingAnchor\.constraint\(equalTo: button\.leadingAnchor\),
            blurView\.trailingAnchor\.constraint\(equalTo: button\.trailingAnchor\),
            button\.widthAnchor\.constraint\(equalToConstant: 40\),
            button\.heightAnchor\.constraint\(equalToConstant: 40\)
        \]\)
        
        return button
    \}\(\)"""

new_button = """    private lazy var backButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        config.baseForegroundColor = .label
        config.background.visualEffect = UIBlurEffect(style: .systemThickMaterial)
        config.background.strokeColor = .systemGray4
        config.background.strokeWidth = 0.5
        config.cornerStyle = .capsule
        
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return button
    }()"""

for f in files:
    with open(f, "r") as file:
        content = file.read()
    
    content = re.sub(old_pattern, new_button, content)
    
    with open(f, "w") as file:
        file.write(content)

print("Done style fix 2.")
