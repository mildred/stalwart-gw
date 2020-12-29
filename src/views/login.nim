import templates
import ../common

func login*(com: CommonRequest): string = tmpli html"""
  <form method="POST" action="?">
    <input type="email" name="email" placeholder="email" />
    <input type="password" name="password" placeholder="password" />
    <input type="submit" value="Log-In"/>
  </form>
  """


