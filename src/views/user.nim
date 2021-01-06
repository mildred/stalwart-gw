import templates
import ../common
import ../db/users

func view_user*(com: CommonRequest, user: Email, aliases: seq[Email], super_admin, domain_admin, user_super_admin, user_domain_admin: bool): string = tmpli html"""
  <p>Back to <a href="$(com.prefix)/domains/$(user.domain)">$(user.domain)</a></p>
  $if aliases.len > 0 {
    <h2>Alias</h2>
    <p>Redirects to:</p>
    <ul>
    $for alias in aliases {
      <li><a href="$(com.prefix)/users/$alias">$alias</a></li>
    }
    </ul>
  }
  $if super_admin or domain_admin {
    <h2>Permissions for $user</h2>
    <ul>
      $if super_admin {
        <li>
          Super admin:
          $if user_super_admin {
            <strong>yes</strong>
          }
          $else {
            <strong>no</strong>
          }
        </li>
      }
      <li>
        Domain admin:
          $if user_super_admin {
            <em>N/A</em>
          }
          $elif user_domain_admin {
            <strong>yes</strong>
          }
          $else {
            <strong>no</strong>
          }
      </li>
    </ul>
  }
  <h2>Change password</h2>
  <form method="post">
    <input type="hidden" name="email" value="$user" />
    <input type="password" name="password1" placeholder="password" />
    <input type="password" name="password2" placeholder="password (confirmation)" />
    <input type="submit" value="Change"/>
  </form>
  """


