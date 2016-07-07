from .settings import *  # NOQA


TEST_RUNNER = 'django.test.runner.DiscoverRunner'
DEBUG = True
TEMPLATE_DEBUG = False
SECRET_KEY = 'nothing'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}
EMAIL_BACKEND = 'django.core.mail.backends.dummy.ConsoleBackend'
