import templates

func signup*(): string = tmpli html"""
  <form method="POST" action="?">
    <input type="email" name="email" placeholder="email" />
    <input type="password" name="password1" placeholder="password" />
    <input type="password" name="password2" placeholder="password (confirmation)" />
    <input type="submit" value="Sign Up"/>
  </form>
  """


