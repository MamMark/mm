interface TagnetAdapter<tagnet_adapter_type>
{
  command bool get_value(tagnet_adapter_type *t, uint8_t *len);
}
