import templates
import ../common
import ../db/users

func home*(com: CommonRequest, user: Email, super_admin, domain_admin: bool, admin_domains: seq[string], domain_users: seq[User]): string = tmpli html"""
    <p>
      You are signed in as <strong>$user</strong>.
    </p>
    $if super_admin {
      <p>
        You are super administrator.
        <a href="$(com.prefix)/users#h-add-new-user">Create user</a>
      </p>
    }
    $if admin_domains.len > 0 {
      <p>
        You are administrator for the following domains:
        <ul>
          $for domain in admin_domains {
            <li><a href="$(com.prefix)/domains/$domain">$domain</a></li>
          }
        </ul>
      </p>
      <p>
        Users of your domain:
        <ul>
          $for user in domain_users {
            <li>
              $if user.domain_admin {
                <strong>
                  <a href="$(com.prefix)/users/$(user.email)">$(user.email)</a>
                </strong>
                <em>($(user.email.domain) administrator)</em>
              }
              $else {
                <a href="$(com.prefix)/users/$(user.email)">$(user.email)</a>
              }
              $if user.super_admin {
                <em>(super admin)</em>
              }
            </li>
          }
          $if domain_admin {
            <li><em><a href="$(com.prefix)/domains/$(user.domain)#h-add-new-user">Add a new user to $(user.domain)</a></em></li>
          }
        </ul>
      </p>
    }
  """


