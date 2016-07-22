"""Test models"""
from __future__ import unicode_literals

from django.db import models
from django.utils.encoding import python_2_unicode_compatible


@python_2_unicode_compatible
class TestModel(models.Model):
    """Just a test, move along"""

    name = models.CharField(
        verbose_name='Name',
        max_length=64,
    )

    def __str__(self):
        return self.name

    class Meta:
        ordering = ['name']
