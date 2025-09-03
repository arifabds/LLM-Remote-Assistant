use once_cell::sync::Lazy;
use regex::Regex;

static DANGEROUS_PATTERN: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r#"\b(os|shutil|subprocess|sys|rmtree|remove|system|execute|eval|exec)\b"#).unwrap()
});

pub fn analyze_code(code: &str) -> bool {
    !DANGEROUS_PATTERN.is_match(code)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_safe_code() {
        let safe_code = "print('Hello, world!')\nresult = 2 + 2";
        assert_eq!(analyze_code(safe_code), true);
    }

    #[test]
    fn test_dangerous_code_with_os() {
        let dangerous_code = "import os\nos.system('rm -rf /')";
        assert_eq!(analyze_code(dangerous_code), false);
    }

    #[test]
    fn test_dangerous_code_with_subprocess() {
        let dangerous_code = "import subprocess\nsubprocess.run(['ls'])";
        assert_eq!(analyze_code(dangerous_code), false);
    }
    
    #[test]
    fn test_dangerous_code_with_shutil() {
        let dangerous_code = "import shutil\nshutil.rmtree('/some/dir')";
        assert_eq!(analyze_code(dangerous_code), false);
    }

    #[test]
    fn test_code_with_substring_of_dangerous_word() {
        let code = "process_data = True";
        assert_eq!(analyze_code(code), true);
    }

    #[test]
    fn test_empty_code() {
        let empty_code = "";
        assert_eq!(analyze_code(empty_code), true);
    }
}