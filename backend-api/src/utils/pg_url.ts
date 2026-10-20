export function semSslMode(url: string): string {
  return url.replace(/([?&])sslmode=[^&]*(&?)/, '$1$2').replace(/[?&]$/, '');
}
