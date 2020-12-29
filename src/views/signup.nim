import templates
import ../common

func signup*(com: CommonRequest, domain: string): string = tmpli html"""
  <form method="POST" action="?domain=$domain">
    <input type="email" name="email" placeholder="email" />
    $if domain != "" {
      <span>@$domain</span>
    }
    <input type="password" name="password1" placeholder="password" />
    <input type="password" name="password2" placeholder="password (confirmation)" />
    <input type="submit" value="Sign Up"/>
  </form>
  """


