Some security and other review feedback: 

You're using an Express server, but not using Helmet. Helmet can help protect your app from some well-known web vulnerabilities by setting HTTP headers. Examples are HSTS headers that enforce SSL, CSP headers that protect against XSS attacks.Other headers protect against putting your app in an iframe to launch social engineering attacks which could be used for account takeovers.


How do I fix it?

Use the Helmet express middleware with: 
const helmet = require("helmet"); 
 app.use(helmet());

Subissues

1
Subissue
backend
droid-news-server
server.js

High
Line 11 in server.js

const app = express();


We detected some exposed secrets in the git history of droid-news-server. The secrets were found in lib/firebase_options.dart and lib/combined_dart_code.tXT

How do I fix it?

If this API key is harmless, you can ignore this issue. If not, we would advise to move the secret out of the git repository by either injecting it via the environment or even better, by using a tool such as AWS Secrets Manager to inject the secrets at run-time. After that, it should be possible to invalidate the current secret and regenerate a new one.

Note: Exposed secrets need to be marked as resolved manually. Even after removal it will still be available in the git history of your repository. That means it could still leak if someone has access to your source code.

Subissues

6
Subissue
Author
backend
droid-news-server
apiKey: '***********************************t8go'

High
Line 57 in lib/firebase_options.dart

View commit
debashishdeb1

***********************************Usc8'

High
Line 65 in lib/firebase_options.dart

View commit
debashishdeb1

apiKey: '***********************************DA-g'

High
Line 47 in lib/firebase_options.dart

View commit
debashishdeb1

***********************************Usc8'

Medium
Line 4980 in lib/combined_dart_code.tXT

View commit
Downgraded: Secret located in deleted file

debashishdeb1

apiKey: '***********************************t8go'

Medium
Line 4972 in lib/combined_dart_code.tXT

View commit
Downgraded: Secret located in deleted file

debashishdeb1

apiKey: '***********************************DA-g'

Medium
Line 4962 in lib/combined_dart_code.tXT

View commit
Downgraded: Secret located in deleted file


We detected some exposed secrets in the git history of droid-news-server. The secrets were found in .env

How do I fix it?

If this API key is harmless, you can ignore this issue. If not, we would advise to move the secret out of the git repository by either injecting it via the environment or even better, by using a tool such as AWS Secrets Manager to inject the secrets at run-time. After that, it should be possible to invalidate the current secret and regenerate a new one.

Note: Exposed secrets need to be marked as resolved manually. Even after removal it will still be available in the git history of your repository. That means it could still leak if someone has access to your source code.

Subissues

2
Subissue
Author
backend
droid-news-server
API_KEY=****************************ef85

High
Line 2 in .env



API_KEY=****************************b087

Medium
Line 1 in .env

Downgraded: Detection uncertain

The 'android:exported' sets whether a component (activity, service, broadcast receiver, etc.) can be launched by any other app. The AndroidManifest.xml file is not configured with a value for 'android:exported'. For older android versions, this defaults to true. This configuration increases the risk of unauthorized access and data leakage.

How do I fix it?

Set 'android:exported' to false for components that don't require external access. If they do, make sure you do not trust the event input and ignore this issue.
More information

Subissues

2
Subissue
backend
droid-news-server
android/app/src/debug/AndroidManifest.xml

Medium
Line 2 - 5 in AndroidManifest.xml

<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
</manifest>
View code analysis
android/app/src/profile/AndroidManifest.xml

Medium
Line 2 - 5 in AndroidManifest.xml

<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
</manifest>
View code analysis


We detected some exposed secrets in the git history of droid-news-server. The secrets were found in test/combined_test_code.dart and test/security/logging_security_test.dart

How do I fix it?

If this API key is harmless, you can ignore this issue. If not, we would advise to move the secret out of the git repository by either injecting it via the environment or even better, by using a tool such as AWS Secrets Manager to inject the secrets at run-time. After that, it should be possible to invalidate the current secret and regenerate a new one.

Note: Exposed secrets need to be marked as resolved manually. Even after removal it will still be available in the git history of your repository. That means it could still leak if someone has access to your source code.

Subissues

6
Subissue
Author
backend
droid-news-server
Password = '***************d123'

Low
Line 5813 in test/combined_test_code.dart

View commit
Downgraded: Secret located in a test file

debashishdeb1

Key = '************************************.xxx'

Low
Line 5799 in test/combined_test_code.dart

View commit
Downgraded: Secret located in a test file

debashishdeb1

Token = '***************(...)***************ture

Low
Line 5754 in test/combined_test_code.dart

View commit
Downgraded: Secret located in a test file

debashishdeb1

Password = '***************d123'

Low
Line 90 in test/security/logging_security_test.dart

View commit
Downgraded: Secret located in a test file

debashishdeb1

Key = '************************************.xxx'

Low
Line 76 in test/security/logging_security_test.dart

View commit
Downgraded: Secret located in a test file

debashishdeb1

Token = '***************(...)***************ture

Low
Line 31 in test/security/logging_security_test.dart

View commit
Downgraded: Secret located in a test file


This is the package maintainer's summary.

body-parser 2.2.0 is vulnerable to denial of service due to inefficient handling of URL-encoded bodies with very large numbers of parameters. An attacker can send payloads containing thousands of parameters within the default 100KB request size limit, causing elevated CPU and memory usage. This can lead to service slowdown or partial outages under sustained malicious traffic.
This issue is addressed in version 2.2.1.The worst case impact for these vulnerabilities can be "Attacker can trigger DOS-attack".

Show more
Does this affect me?

With the information Aikido has about your environment and our reachability analysis, we have determined that this vulnerability can affect your environment.


How are you using it
How do I fix it?

We recommend updating from 2.2.0 to 2.2.1.

Subissues

1
Subissue
Fix
backend
droid-news-server
CVE-2025-13466

Low
package-lock.json

View reachability analysis
Downgraded: Only impacts performance, not security

2.2.0 => 2.2.1


If an attacker can control the URL input leading into this HTTP request, the attack might be able to perform an SSRF attack. This kind of attack is even more dangerous if the application returns the response of the request to the user. It could allow them to retrieve information from higher privileged services within the network (such as the metadata service, which is commonly available in cloud services, and could allow them to retrieve credentials).

Show more
How do I fix it?

If possible, only allow requests to allowlisting domains. If not, consult the article linked above to learn about other mitigating techniques such as disabling redirects, blocking private IPs and making sure private services have internal authentication. If you return data coming from the request to the user, validate the data before returning it to make sure you don't return random data.
More information

Show more
Subissues

1
Subissue
backend
droid-news-server
check_sources.py

Low
Line 15 in check_sources.py

response = requests.head(url, timeout=timeout, allow_redirects=True)
View code analysis
Downgraded: AI assessed finding as hard to exploit

Affected versions of this package are affected by insecure randomness due to the use of `Math.random()` in a Firebase custom UUID function that could create significant security vulnerabilities. This weak random number generator enables potential attackers to predict UUIDs, which can lead to collisions and unauthorized access to resources.

Show more
Does this affect me?

You are affected if you are using a version that falls within the vulnerable range.


How are you using it
How do I fix it?

Upgrade the `@firebase/util` library to the patch version.

Subissues

1
Subissue
Fix
backend
droid-news-server
AIKIDO-2025-10025

Low
functions/package-lock.json

View reachability analysis
1.10.0 => 1.10.3

